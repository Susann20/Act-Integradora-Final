%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tabla_simbolos.h"

extern int linea;
extern int yylineno;
int yylex();
void yyerror(const char *s);
extern int errores_lexicos;
extern int errores_sintacticos;
extern int errores_semanticos;

char ambito_actual[64] = "global";
%}

%union {
    int ival;
    double dval;
    char* str;
    Tipo tipo;
}

%token <str> ID LIB LIT_STRING
%token <ival> LIT_INT
%token <dval> LIT_DOUBLE
%token <tipo> TIPO

%token INCLUDE DEFINE CONST MAIN IF ELSE WHILE FOR RETURN
%token EQ NE LE GE AND OR LT GT NOT
%token ASIGN MAS MENOS POR DIV
%token LPAREN RPAREN LBRACE RBRACE PUNTO_COMA COMA

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
programa:
    preprocesador lista_declaraciones
    ;

preprocesador:
    /* vacío */
    | preprocesador INCLUDE LIB { /* Registrar librería (opcional) */ }
    | preprocesador DEFINE ID LIT_INT {
        if (existe_en_ambito($3, "global")) {
            printf("Error semántico en línea %d: macro '%s' ya definida.\n", yylineno, $3);
            errores_semanticos++;
        } else {
            insertar_simbolo($3, MACRO, TIPO_INT, 0, 1, "global");
        }
    }
    | preprocesador DEFINE ID LIT_DOUBLE {
        if (existe_en_ambito($3, "global")) {
            printf("Error semántico en línea %d: macro '%s' ya definida.\n", yylineno, $3);
            errores_semanticos++;
        } else {
            insertar_simbolo($3, MACRO, TIPO_DOUBLE, 0, 1, "global");
        }
    }
    ;

lista_declaraciones:
    /* vacío */
    | lista_declaraciones declaracion
    ;

declaracion:
    CONST TIPO ID ASIGN expresion PUNTO_COMA {
        if (existe_en_ambito($3, "global")) {
            printf("Error semántico en línea %d: símbolo '%s' ya declarado.\n", yylineno, $3);
            errores_semanticos++;
        } else {
            insertar_simbolo($3, CONST, $2, 0, 1, "global");
        }
    }
    | TIPO ID LPAREN parametros RPAREN LBRACE cuerpo RBRACE {
        if (existe_en_ambito($2, "global")) {
            printf("Error semántico en línea %d: función '%s' ya declarada.\n", yylineno, $2);
            errores_semanticos++;
        } else {
            int aridad = 0;
            Simbolo* s = buscar_simbolo("__params_contador", "global");
            if (s) aridad = s->aridad;
            insertar_simbolo($2, FUNC, $1, aridad, 0, "global");
        }
        strcpy(ambito_actual, "global");
    }
    | MAIN LPAREN RPAREN LBRACE {
    strcpy(ambito_actual, "main"); // Cambiamos el ámbito a 'main' para las variables locales
} cuerpo RBRACE {
    strcpy(ambito_actual, "global"); // Al salir de main, volvemos a global
}

parametros:
    /* vacío */ { insertar_simbolo("__params_contador", VAR, TIPO_INT, 0, 0, "global"); }
    | lista_params { insertar_simbolo("__params_contador", VAR, TIPO_INT, 1, 0, "global"); }
    ;

lista_params:
    TIPO ID { insertar_simbolo($2, VAR, $1, 0, 0, "global"); }
    | lista_params COMA TIPO ID {
        insertar_simbolo($4, VAR, $3, 0, 0, "global");
        Simbolo* s = buscar_simbolo("__params_contador", "global");
        if (s) s->aridad++;
    }
    ;

cuerpo:
    /* vacío */
    | cuerpo sentencia
    ;

sentencia:
    TIPO ID ASIGN expresion PUNTO_COMA {
        if (existe_en_ambito($2, ambito_actual)) {
            printf("Error semántico en línea %d: redeclaración de '%s'.\n", yylineno, $2);
            errores_semanticos++;
        } else {
            insertar_simbolo($2, VAR, $1, 0, 0, ambito_actual);
        }
    }
    | ID ASIGN expresion PUNTO_COMA {
        Simbolo* s = buscar_simbolo($1, ambito_actual);
        if (!s) {
            printf("Error semántico en línea %d: variable '%s' no declarada en el ámbito actual.\n", yylineno, $1);
            errores_semanticos++;
        } else if (s->es_constante) {
            printf("Error semántico en línea %d: no se puede asignar un valor a la constante '%s'.\n", yylineno, $1);
            errores_semanticos++;
        }
    }
    | IF LPAREN condicion RPAREN LBRACE cuerpo RBRACE %prec LOWER_THAN_ELSE
    | IF LPAREN condicion RPAREN LBRACE cuerpo RBRACE ELSE LBRACE cuerpo RBRACE
    | WHILE LPAREN condicion RPAREN LBRACE cuerpo RBRACE
    | RETURN expresion PUNTO_COMA
    | ID LPAREN argumentos RPAREN PUNTO_COMA {
        Simbolo* s = buscar_simbolo($1, ambito_actual);
        if (!s) {
            printf("Error semántico en línea %d: función '%s' no declarada.\n", yylineno, $1);
            errores_semanticos++;
        }
    }
    | error PUNTO_COMA { yyerrok; errores_sintacticos++; }
    ;

condicion:
    expresion_relacional
    ;

expresion_relacional:
    ID {
        Simbolo* s = buscar_simbolo($1, ambito_actual);
        if (!s) {
            printf("Error semántico en línea %d: variable '%s' no declarada en condición.\n", yylineno, $1);
            errores_semanticos++;
        }
    }
    | expresion_relacional EQ expresion_relacional
    | expresion_relacional NE expresion_relacional
    | expresion_relacional LT expresion_relacional
    | expresion_relacional GT expresion_relacional
    | expresion_relacional LE expresion_relacional
    | expresion_relacional GE expresion_relacional
    | expresion_relacional AND expresion_relacional
    | expresion_relacional OR expresion_relacional
    | NOT expresion_relacional
    | LIT_INT
    | LIT_DOUBLE
    | LPAREN expresion_relacional RPAREN
    ;

argumentos:
    /* vacío */
    | lista_args
    ;

lista_args:
    expresion
    | lista_args COMA expresion
    ;

expresion:
    LIT_INT
    | LIT_DOUBLE
    | ID {
        Simbolo* s = buscar_simbolo($1, ambito_actual);
        if (!s) {
            printf("Error semántico en línea %d: variable '%s' no declarada en el ámbito actual.\n", yylineno, $1);
            errores_semanticos++;
        }
    }
    | ID LPAREN argumentos RPAREN {
        Simbolo* s = buscar_simbolo($1, ambito_actual);
        if (!s) {
            printf("Error semántico en línea %d: función '%s' no declarada.\n", yylineno, $1);
            errores_semanticos++;
        }
    }
    | expresion MAS expresion
    | expresion MENOS expresion
    | expresion POR expresion
    | expresion DIV expresion
    | LPAREN expresion RPAREN
    ;

%%
void yyerror(const char *s) {
    printf("Error sintáctico en línea %d: %s\n", yylineno, s);
    errores_sintacticos++;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Uso: %s <archivo.c>\n", argv[0]);
        return 1;
    }
    FILE *f = fopen(argv[1], "r");
    if (!f) {
        printf("No se pudo abrir el archivo: %s\n", argv[1]);
        return 1;
    }
    extern FILE *yyin;
    yyin = f;
    init_tabla();
    yyparse();
    fclose(f);
    imprimir_tabla();
    return 0;
}