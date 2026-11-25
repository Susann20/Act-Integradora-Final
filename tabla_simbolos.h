#ifndef TABLA_SIMBOLOS_H
#define TABLA_SIMBOLOS_H

#define MAX_SIMBOLOS 100

typedef enum { VAR, CONST, FUNC, MACRO } Clase;
typedef enum { TIPO_INT, TIPO_DOUBLE, TIPO_VOID, TIPO_UNDEF } Tipo;

typedef struct {
    char nombre[64];
    Clase clase;
    Tipo tipo;
    int aridad;           // Para funciones
    int es_constante;     // 1 si es const o macro
    char ambito[64];      // "global" o nombre de la función
} Simbolo;

// Funciones de la tabla
void init_tabla();
int insertar_simbolo(const char* nombre, Clase clase, Tipo tipo, int aridad, int es_constante, const char* ambito);
Simbolo* buscar_simbolo(const char* nombre, const char* ambito_actual);
int existe_en_ambito(const char* nombre, const char* ambito);
void imprimir_tabla();
void liberar_tabla();

// Variables globales para conteo de errores
extern int errores_lexicos;
extern int errores_sintacticos;
extern int errores_semanticos;

#endif