#ifndef TABLA_SIMBOLOS_H
#define TABLA_SIMBOLOS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    TIPO_INT,
    TIPO_DOUBLE,
    TIPO_VOID,
    TIPO_DESCONOCIDO
} TipoDato;

typedef enum {
    CLASE_VARIABLE,
    CLASE_CONSTANTE,
    CLASE_MACRO,
    CLASE_FUNCION,
    CLASE_PARAMETRO
} ClaseSimbolo;

typedef struct Simbolo {
    char nombre[64];
    ClaseSimbolo clase;
    TipoDato tipo;
    char ambito[64];
    int aridad;
    int es_constante;
    TipoDato tipos_parametros[16];
    struct Simbolo *siguiente;
} Simbolo;

void inicializar_tabla();
Simbolo* buscar_simbolo(const char *nombre, const char *ambito);
Simbolo* buscar_en_ambito_exacto(const char *nombre, const char *ambito);
int insertar_simbolo(const char *nombre, ClaseSimbolo clase, TipoDato tipo, const char *ambito, int aridad, int es_constante);
void registrar_parametro_funcion(const char *nombre_func, int indice, TipoDato tipo_param);
const char* tipo_a_cadena(TipoDato tipo);
const char* clase_a_cadena(ClaseSimbolo clase);
void imprimir_tabla_simbolos();
void liberar_tabla();

#endif