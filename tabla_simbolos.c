#include "tabla_simbolos.h"

static Simbolo *cabeza = NULL;

void inicializar_tabla() {
    cabeza = NULL;
    // Registrar funciones estándar integradas (ej. printf)
    insertar_simbolo("printf", CLASE_FUNCION, TIPO_INT, "global", -1, 0);
}

Simbolo* buscar_en_ambito_exacto(const char *nombre, const char *ambito) {
    Simbolo *actual = cabeza;
    while (actual != NULL) {
        if (strcmp(actual->nombre, nombre) == 0 && strcmp(actual->ambito, ambito) == 0) {
            return actual;
        }
        actual = actual->siguiente;
    }
    return NULL;
}

Simbolo* buscar_simbolo(const char *nombre, const char *ambito) {
    // Primero buscar en el ámbito local actual
    Simbolo *local = buscar_en_ambito_exacto(nombre, ambito);
    if (local != NULL) {
        return local;
    }
    // Si no está en local, buscar en el ámbito global
    if (strcmp(ambito, "global") != 0) {
        return buscar_en_ambito_exacto(nombre, "global");
    }
    return NULL;
}

int insertar_simbolo(const char *nombre, ClaseSimbolo clase, TipoDato tipo, const char *ambito, int aridad, int es_constante) {
    if (buscar_en_ambito_exacto(nombre, ambito) != NULL) {
        return 0; // Error: ya existe en el mismo ámbito
    }

    Simbolo *nuevo = (Simbolo*)malloc(sizeof(Simbolo));
    strncpy(nuevo->nombre, nombre, 63);
    nuevo->nombre[63] = '\0';
    nuevo->clase = clase;
    nuevo->tipo = tipo;
    strncpy(nuevo->ambito, ambito, 63);
    nuevo->ambito[63] = '\0';
    nuevo->aridad = aridad;
    nuevo->es_constante = es_constante;
    for (int i = 0; i < 16; i++) {
        nuevo->tipos_parametros[i] = TIPO_DESCONOCIDO;
    }
    nuevo->siguiente = NULL;

    if (cabeza == NULL) {
        cabeza = nuevo;
    } else {
        Simbolo *temp = cabeza;
        while (temp->siguiente != NULL) {
            temp = temp->siguiente;
        }
        temp->siguiente = nuevo;
    }
    return 1;
}

void registrar_parametro_funcion(const char *nombre_func, int indice, TipoDato tipo_param) {
    Simbolo *func = buscar_en_ambito_exacto(nombre_func, "global");
    if (func != NULL && indice >= 0 && indice < 16) {
        func->tipos_parametros[indice] = tipo_param;
    }
}

const char* tipo_a_cadena(TipoDato tipo) {
    switch (tipo) {
        case TIPO_INT: return "int";
        case TIPO_DOUBLE: return "double";
        case TIPO_VOID: return "void";
        default: return "desconocido";
    }
}

const char* clase_a_cadena(ClaseSimbolo clase) {
    switch (clase) {
        case CLASE_VARIABLE: return "Variable";
        case CLASE_CONSTANTE: return "Constante";
        case CLASE_MACRO: return "Macro";
        case CLASE_FUNCION: return "Funcion";
        case CLASE_PARAMETRO: return "Parametro";
        default: return "Otro";
    }
}

void imprimir_tabla_simbolos() {
    printf("\n================================================================================\n");
    printf("                           TABLA DE SIMBOLOS (SlimC)                            \n");
    printf("================================================================================\n");
    printf("%-18s | %-12s | %-10s | %-14s | %-6s | %-9s\n", 
           "Nombre", "Clase", "Tipo", "Ambito", "Aridad", "Constante");
    printf("--------------------------------------------------------------------------------\n");

    Simbolo *actual = cabeza;
    while (actual != NULL) {
        if (strcmp(actual->nombre, "printf") != 0) { // Omitir built-in interno o mostrarlo
            char aridad_str[10];
            if (actual->clase == CLASE_FUNCION) {
                snprintf(aridad_str, sizeof(aridad_str), "%d", actual->aridad);
            } else {
                strcpy(aridad_str, "-");
            }
            printf("%-18s | %-12s | %-10s | %-14s | %-6s | %-9s\n",
                   actual->nombre,
                   clase_a_cadena(actual->clase),
                   tipo_a_cadena(actual->tipo),
                   actual->ambito,
                   aridad_str,
                   actual->es_constante ? "Si" : "No");
        }
        actual = actual->siguiente;
    }
    printf("================================================================================\n");
}

void liberar_tabla() {
    Simbolo *actual = cabeza;
    while (actual != NULL) {
        Simbolo *sig = actual->siguiente;
        free(actual);
        actual = sig;
    }
    cabeza = NULL;
}