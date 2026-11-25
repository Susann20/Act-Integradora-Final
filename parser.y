%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tabla_simbolos.h"

extern int yylex();
extern int yylineno;
extern int errores_lexicos;
extern FILE *yyin;

void yyerror(const char *s);

int errores_sintacticos = 0;
int errores_semanticos = 0;

char ambito_actual[64] = "global";
TipoDato tipo_retorno_actual = TIPO_VOID;

/* Estructuras auxiliares para validación de parámetros y argumentos */
typedef struct {
    char nombre[64];
    TipoDato tipo;
} ParamTemp;

ParamTemp params_temp[16];
int num_params_temp = 0;

TipoDato args_temp[16];
int num_args_temp = 0;

int es_compatible(TipoDato esperado, TipoDato recibido) {
    if (esperado == TIPO_DESCONOCIDO || recibido == TIPO_DESCONOCIDO) return 1;
    if (esperado == recibido) return 1;
    /* Promoción implícita int -> double permitida, double -> int genera incompatibilidad */
    if (esperado == TIPO_DOUBLE && recibido == TIPO_INT) return 1;
    return 0;
}
%}

%union {
    int ival;
    double dval;
    char *str;
    TipoDato tipo;
}

%token INCLUDE DEFINE CONST INT DOUBLE MAIN RETURN IF ELSE WHILE
%token EQ NEQ LE GE LT GT AND OR NOT
%token PLUS MINUS MULT DIV ASSIGN
%token LPAREN RPAREN LBRACE RBRACE SEMI COMMA
%token <ival> INT_LITERAL
%token <dval> FLOAT_LITERAL
%token <str> STRING_LITERAL HEADER ID

%type <tipo> tipo expresion termino factor llamada_funcion

/* Precedencia y asociatividad de operadores */
%right ASSIGN
%left OR
%left AND
%left EQ NEQ
%left LT GT LE GE
%left PLUS MINUS
%left MULT DIV
%right NOT UMINUS

%%

programa:
    lista_elementos_globales funcion_main
    ;

lista_elementos_globales:
    /* vacío */
    | lista_elementos_globales elemento_global
    ;

elemento_global:
    directiva_include
    | directiva_define
    | declaracion_constante_global
    | declaracion_variable_global
    | definicion_funcion
    | error SEMI {
        fprintf(stderr, "Error sintactico en linea %d: declaracion global mal formada.\n", yylineno);
        yyerrok;
    }
    ;

directiva_include:
    INCLUDE HEADER {
        free($2);
    }
    ;

directiva_define:
    DEFINE ID INT_LITERAL {
        if (!insertar_simbolo($2, CLASE_MACRO, TIPO_INT, "global", 0, 1)) {
            fprintf(stderr, "Error semantico en linea %d: macro '%s' ya definida.\n", yylineno, $2);
            errores_semanticos++;
        }
        free($2);
    }
    | DEFINE ID FLOAT_LITERAL {
        if (!insertar_simbolo($2, CLASE_MACRO, TIPO_DOUBLE, "global", 0, 1)) {
            fprintf(stderr, "Error semantico en linea %d: macro '%s' ya definida.\n", yylineno, $2);
            errores_semanticos++;
        }
        free($2);
    }
    ;

tipo:
    INT      { $$ = TIPO_INT; }
    | DOUBLE { $$ = TIPO_DOUBLE; }
    ;

declaracion_constante_global:
    CONST tipo ID ASSIGN expresion SEMI {
        if (!insertar_simbolo($3, CLASE_CONSTANTE, $2, "global", 0, 1)) {
            fprintf(stderr, "Error semantico en linea %d: constante '%s' ya declarada.\n", yylineno, $3);
            errores_semanticos++;
        } else if (!es_compatible($2, $5)) {
            fprintf(stderr, "Error semantico en linea %d: tipo incompatible en inicializacion de constante '%s'.\n", yylineno, $3);
            errores_semanticos++;
        }
        free($3);
    }
    ;

declaracion_variable_global:
    tipo ID SEMI {
        if (!insertar_simbolo($2, CLASE_VARIABLE, $1, "global", 0, 0)) {
            fprintf(stderr, "Error semantico en linea %d: variable global '%s' ya declarada.\n", yylineno, $2);
            errores_semanticos++;
        }
        free($2);
    }
    | tipo ID ASSIGN expresion SEMI {
        if (!insertar_simbolo($2, CLASE_VARIABLE, $1, "global", 0, 0)) {
            fprintf(stderr, "Error semantico en linea %d: variable global '%s' ya declarada.\n", yylineno, $2);
            errores_semanticos++;
        } else if (!es_compatible($1, $4)) {
            fprintf(stderr, "Error semantico en linea %d: tipo incompatible al inicializar '%s'.\n", yylineno, $2);
            errores_semanticos++;
        }
        free($2);
    }
    ;

definicion_funcion:
    tipo ID LPAREN {
        num_params_temp = 0;
        strncpy(ambito_actual, $2, 63);
        tipo_retorno_actual = $1;
    } lista_parametros RPAREN {
        if (!insertar_simbolo($2, CLASE_FUNCION, $1, "global", num_params_temp, 0)) {
            fprintf(stderr, "Error semantico en linea %d: funcion '%s' ya declarada.\n", yylineno, $2);
            errores_semanticos++;
        } else {
            for (int i = 0; i < num_params_temp; i++) {
                registrar_parametro_funcion($2, i, params_temp[i].tipo);
                if (!insertar_simbolo(params_temp[i].nombre, CLASE_PARAMETRO, params_temp[i].tipo, ambito_actual, 0, 0)) {
                    fprintf(stderr, "Error semantico en linea %d: parametro '%s' duplicado en '%s'.\n", yylineno, params_temp[i].nombre, $2);
                    errores_semanticos++;
                }
            }
        }
    } bloque {
        strcpy(ambito_actual, "global");
        tipo_retorno_actual = TIPO_VOID;
        free($2);
    }
    ;

lista_parametros:
    /* vacío */
    | parametros
    ;

parametros:
    parametro
    | parametros COMMA parametro
    ;

parametro:
    tipo ID {
        if (num_params_temp < 16) {
            strncpy(params_temp[num_params_temp].nombre, $2, 63);
            params_temp[num_params_temp].tipo = $1;
            num_params_temp++;
        }
        free($2);
    }
    ;

funcion_main:
    INT MAIN LPAREN RPAREN {
        strcpy(ambito_actual, "main");
        tipo_retorno_actual = TIPO_INT;
        insertar_simbolo("main", CLASE_FUNCION, TIPO_INT, "global", 0, 0);
    } bloque {
        strcpy(ambito_actual, "global");
        tipo_retorno_actual = TIPO_VOID;
    }
    ;

bloque:
    LBRACE lista_sentencias RBRACE
    ;

lista_sentencias:
    /* vacío */
    | lista_sentencias sentencia
    ;

sentencia:
    declaracion_local
    | asignacion
    | sentencia_if
    | sentencia_while
    | sentencia_return
    | llamada_funcion SEMI
    | error SEMI {
        fprintf(stderr, "Error sintactico en linea %d: sentencia invalida antes de ';'.\n", yylineno);
        yyerrok;
    }
    | error RBRACE {
        fprintf(stderr, "Error sintactico en linea %d: bloque mal formado antes de '}'.\n", yylineno);
        yyerrok;
    }
    ;

declaracion_local:
    CONST tipo ID ASSIGN expresion SEMI {
        if (!insertar_simbolo($3, CLASE_CONSTANTE, $2, ambito_actual, 0, 1)) {
            fprintf(stderr, "Error semantico en linea %d: constante local '%s' ya declarada en '%s'.\n", yylineno, $3, ambito_actual);
            errores_semanticos++;
        } else if (!es_compatible($2, $5)) {
            fprintf(stderr, "Error semantico en linea %d: tipo incompatible en constante '%s'.\n", yylineno, $3);
            errores_semanticos++;
        }
        free($3);
    }
    | tipo ID SEMI {
        if (!insertar_simbolo($2, CLASE_VARIABLE, $1, ambito_actual, 0, 0)) {
            fprintf(stderr, "Error semantico en linea %d: variable '%s' ya declarada en '%s'.\n", yylineno, $2, ambito_actual);
            errores_semanticos++;
        }
        free($2);
    }
    | tipo ID ASSIGN expresion SEMI {
        if (!insertar_simbolo($2, CLASE_VARIABLE, $1, ambito_actual, 0, 0)) {
            fprintf(stderr, "Error semantico en linea %d: variable '%s' ya declarada en '%s'.\n", yylineno, $2, ambito_actual);
            errores_semanticos++;
        } else if (!es_compatible($1, $4)) {
            fprintf(stderr, "Error semantico en linea %d: tipo incompatible al inicializar '%s' (se esperaba '%s', se recibio '%s').\n",
                    yylineno, $2, tipo_a_cadena($1), tipo_a_cadena($4));
            errores_semanticos++;
        }
        free($2);
    }
    ;

asignacion:
    ID ASSIGN expresion SEMI {
        Simbolo *s = buscar_simbolo($1, ambito_actual);
        if (s == NULL) {
            fprintf(stderr, "Error semantico en linea %d: variable '%s' no declarada.\n", yylineno, $1);
            errores_semanticos++;
        } else if (s->es_constante) {
            fprintf(stderr, "Error semantico en linea %d: no se puede asignar un valor a la constante '%s'.\n", yylineno, $1);
            errores_semanticos++;
        } else if (s->clase == CLASE_FUNCION) {
            fprintf(stderr, "Error semantico en linea %d: '%s' es una funcion y no puede recibir asignacion.\n", yylineno, $1);
            errores_semanticos++;
        } else if (!es_compatible(s->tipo, $3)) {
            fprintf(stderr, "Error semantico en linea %d: tipo incompatible en asignacion a '%s' (se esperaba '%s', se recibio '%s').\n",
                    yylineno, $1, tipo_a_cadena(s->tipo), tipo_a_cadena($3));
            errores_semanticos++;
        }
        free($1);
    }
    ;

sentencia_if:
    IF LPAREN condicion_if RPAREN bloque
    | IF LPAREN condicion_if RPAREN bloque ELSE bloque
    ;

condicion_if:
    expresion {
        if ($1 == TIPO_DESCONOCIDO) {
            /* Error ya reportado dentro de la expresión o identificador no declarado */
        } else if ($1 != TIPO_INT && $1 != TIPO_DOUBLE) {
            fprintf(stderr, "Error semantico en linea %d: tipo no numerico en condicion 'if'.\n", yylineno);
            errores_semanticos++;
        }
    }
    ;

sentencia_while:
    WHILE LPAREN condicion_while RPAREN bloque
    ;

condicion_while:
    expresion {
        if ($1 == TIPO_DESCONOCIDO) {
            /* Error ya reportado dentro de la expresión o identificador no declarado */
        } else if ($1 != TIPO_INT && $1 != TIPO_DOUBLE) {
            fprintf(stderr, "Error semantico en linea %d: tipo no numerico en condicion 'while'.\n", yylineno);
            errores_semanticos++;
        }
    }
    ;

sentencia_return:
    RETURN expresion SEMI {
        if (!es_compatible(tipo_retorno_actual, $2)) {
            fprintf(stderr, "Error semantico en linea %d: tipo de retorno incompatible (se esperaba '%s', se recibio '%s').\n",
                    yylineno, tipo_a_cadena(tipo_retorno_actual), tipo_a_cadena($2));
            errores_semanticos++;
        }
    }
    ;

llamada_funcion:
    ID LPAREN {
        num_args_temp = 0;
    } lista_argumentos RPAREN {
        Simbolo *func = buscar_simbolo($1, "global");
        if (func == NULL) {
            fprintf(stderr, "Error semantico en linea %d: funcion '%s' no declarada.\n", yylineno, $1);
            errores_semanticos++;
            $$ = TIPO_DESCONOCIDO;
        } else if (func->clase != CLASE_FUNCION) {
            fprintf(stderr, "Error semantico en linea %d: '%s' no es una funcion.\n", yylineno, $1);
            errores_semanticos++;
            $$ = TIPO_DESCONOCIDO;
        } else {
            if (func->aridad != -1) { // -1 indica función variádica como printf
                if (func->aridad != num_args_temp) {
                    fprintf(stderr, "Error semantico en linea %d: la funcion '%s' espera %d argumento(s), pero recibio %d.\n",
                            yylineno, $1, func->aridad, num_args_temp);
                    errores_semanticos++;
                } else {
                    for (int i = 0; i < num_args_temp; i++) {
                        if (!es_compatible(func->tipos_parametros[i], args_temp[i])) {
                            fprintf(stderr, "Error semantico en linea %d: tipo incompatible en argumento %d de '%s' (se esperaba '%s', se recibio '%s').\n",
                                    yylineno, i + 1, $1,
                                    tipo_a_cadena(func->tipos_parametros[i]),
                                    tipo_a_cadena(args_temp[i]));
                            errores_semanticos++;
                        }
                    }
                }
            }
            $$ = func->tipo;
        }
        free($1);
    }
    ;

lista_argumentos:
    /* vacío */
    | argumentos
    ;

argumentos:
    argumento
    | argumentos COMMA argumento
    ;

argumento:
    expresion {
        if (num_args_temp < 16) {
            args_temp[num_args_temp++] = $1;
        }
    }
    | STRING_LITERAL {
        if (num_args_temp < 16) {
            args_temp[num_args_temp++] = TIPO_DESCONOCIDO;
        }
        free($1);
    }
    ;

expresion:
    expresion PLUS termino {
        if ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) $$ = TIPO_DESCONOCIDO;
        else $$ = ($1 == TIPO_DOUBLE || $3 == TIPO_DOUBLE) ? TIPO_DOUBLE : TIPO_INT;
    }
    | expresion MINUS termino {
        if ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) $$ = TIPO_DESCONOCIDO;
        else $$ = ($1 == TIPO_DOUBLE || $3 == TIPO_DOUBLE) ? TIPO_DOUBLE : TIPO_INT;
    }
    | expresion EQ expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion NEQ expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion LT expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion GT expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion LE expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion GE expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion AND expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | expresion OR expresion {
        $$ = ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | NOT expresion {
        $$ = ($2 == TIPO_DESCONOCIDO) ? TIPO_DESCONOCIDO : TIPO_INT;
    }
    | termino {
        $$ = $1;
    }
    ;

termino:
    termino MULT factor {
        if ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) $$ = TIPO_DESCONOCIDO;
        else $$ = ($1 == TIPO_DOUBLE || $3 == TIPO_DOUBLE) ? TIPO_DOUBLE : TIPO_INT;
    }
    | termino DIV factor {
        if ($1 == TIPO_DESCONOCIDO || $3 == TIPO_DESCONOCIDO) $$ = TIPO_DESCONOCIDO;
        else $$ = ($1 == TIPO_DOUBLE || $3 == TIPO_DOUBLE) ? TIPO_DOUBLE : TIPO_INT;
    }
    | factor {
        $$ = $1;
    }
    ;

factor:
    INT_LITERAL {
        $$ = TIPO_INT;
    }
    | FLOAT_LITERAL {
        $$ = TIPO_DOUBLE;
    }
    | ID {
        Simbolo *s = buscar_simbolo($1, ambito_actual);
        if (s == NULL) {
            fprintf(stderr, "Error semantico en linea %d: variable '%s' no declarada en el ambito actual.\n", yylineno, $1);
            errores_semanticos++;
            $$ = TIPO_DESCONOCIDO;
        } else {
            $$ = s->tipo;
        }
        free($1);
    }
    | llamada_funcion {
        $$ = $1;
    }
    | LPAREN expresion RPAREN {
        $$ = $2;
    }
    | MINUS factor %prec UMINUS {
        $$ = $2;
    }
    ;

%%

void yyerror(const char *s) {
    errores_sintacticos++;
    fprintf(stderr, "Error sintactico en linea %d: %s\n", yylineno, s);
}

int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *archivo = fopen(argv[1], "r");
        if (!archivo) {
            perror("No se pudo abrir el archivo de entrada");
            return 1;
        }
        yyin = archivo;
    }

    inicializar_tabla();
    yyparse();

    imprimir_tabla_simbolos();

    int total_errores = errores_lexicos + errores_sintacticos + errores_semanticos;
    printf("\n--- RESUMEN DEL ANALISIS (SlimC) ---\n");
    printf("Errores lexicos    : %d\n", errores_lexicos);
    printf("Errores sintacticos: %d\n", errores_sintacticos);
    printf("Errores semanticos : %d\n", errores_semanticos);
    printf("Total de errores   : %d\n", total_errores);

    if (total_errores == 0) {
        printf("Resultado: ACCEPT (Programa valido)\n");
    } else {
        printf("Resultado: REJECT (Se encontraron errores)\n");
    }

    liberar_tabla();
    if (argc > 1) fclose(yyin);
    return (total_errores == 0) ? 0 : 1;
}