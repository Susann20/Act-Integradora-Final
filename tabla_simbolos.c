#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "tabla_simbolos.h"

Simbolo tabla[MAX_SIMBOLOS];
int num_simbolos = 0;

int errores_lexicos = 0;
int errores_sintacticos = 0;
int errores_semanticos = 0;

void init_tabla() {
    num_simbolos = 0;
}

int insertar_simbolo(const char* nombre, Clase clase, Tipo tipo, int aridad, int es_constante, const char* ambito) {
    if (num_simbolos >= MAX_SIMBOLOS) return 0;
    Simbolo* s = &tabla[num_simbolos++];
    strncpy(s->nombre, nombre, 63);
    s->clase = clase;
    s->tipo = tipo;
    s->aridad = aridad;
    s->es_constante = es_constante;
    strncpy(s->ambito, ambito, 63);
    return 1;
}

Simbolo* buscar_simbolo(const char* nombre, const char* ambito_actual) {
    // Buscar primero en el ámbito actual, luego en global
    for (int i = num_simbolos - 1; i >= 0; i--) {
        if (strcmp(tabla[i].nombre, nombre) == 0) {
            if (strcmp(tabla[i].ambito, ambito_actual) == 0 || strcmp(tabla[i].ambito, "global") == 0) {
                return &tabla[i];
            }
        }
    }
    return NULL;
}

int existe_en_ambito(const char* nombre, const char* ambito) {
    for (int i = 0; i < num_simbolos; i++) {
        if (strcmp(tabla[i].nombre, nombre) == 0 && strcmp(tabla[i].ambito, ambito) == 0) {
            return 1;
        }
    }
    return 0;
}

void imprimir_tabla() {
    printf("\n================ TABLA DE SÍMBOLOS ================\n");
    printf("%-15s %-10s %-10s %-10s %-10s %-8s\n", "Nombre", "Clase", "Tipo", "Ámbito", "Aridad", "Const");
    printf("---------------------------------------------------\n");
    for (int i = 0; i < num_simbolos; i++) {
        Simbolo* s = &tabla[i];
        const char* clase_str = (s->clase == VAR) ? "VAR" : (s->clase == CONST) ? "CONST" : (s->clase == FUNC) ? "FUNC" : "MACRO";
        const char* tipo_str = (s->tipo == TIPO_INT) ? "int" : (s->tipo == TIPO_DOUBLE) ? "double" : (s->tipo == TIPO_VOID) ? "void" : "?";
        printf("%-15s %-10s %-10s %-10s %-10d %-8s\n", s->nombre, clase_str, tipo_str, s->ambito, s->aridad, s->es_constante ? "Sí" : "No");
    }
    printf("===================================================\n");
    printf("Total errores -> Léxicos: %d | Sintácticos: %d | Semánticos: %d\n\n", 
           errores_lexicos, errores_sintacticos, errores_semanticos);
}

void liberar_tabla() { /* Nada que liberar (estático) */ }