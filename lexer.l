%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tabla_simbolos.h"
#include "parser.tab.h"

int errores_lexicos = 0;
%}

%option noyywrap
%option yylineno

DIGITO      [0-9]
LETRA       [a-zA-Z_]
ID          {LETRA}({LETRA}|{DIGITO})*
ENTERO      {DIGITO}+
FLOTANTE    {DIGITO}+\.{DIGITO}+
CADENA      \"([^\\\n]|(\\.))*\"
LIBRERIA    <[a-zA-Z0-9_./]+\.h>

%x COMENTARIO

%%

    /* Comentarios de una línea */
"//".*                  { /* Ignorar comentario de una línea; \n se procesa abajo */ }

    /* Comentarios multilínea preservando yylineno */
"/*"                    { BEGIN(COMENTARIO); }
<COMENTARIO>"*/"        { BEGIN(INITIAL); }
<COMENTARIO>\n          { /* yylineno se incrementa automáticamente */ }
<COMENTARIO>.           { /* Ignorar caracteres dentro del comentario */ }
<COMENTARIO><<EOF>>     {
                            fprintf(stderr, "Error lexico en linea %d: comentario multilinea sin cerrar.\n", yylineno);
                            errores_lexicos++;
                            BEGIN(INITIAL);
                        }

    /* Directivas de preprocesador */
"#include"              { return INCLUDE; }
"#define"               { return DEFINE; }
{LIBRERIA}              { yylval.str = strdup(yytext); return HEADER; }

    /* Palabras reservadas */
"int"                   { return INT; }
"double"                { return DOUBLE; }
"const"                 { return CONST; }
"main"                  { return MAIN; }
"return"                { return RETURN; }
"if"                    { return IF; }
"else"                  { return ELSE; }
"while"                 { return WHILE; }

    /* Operadores relacionales y lógicos */
"=="                    { return EQ; }
"!="                    { return NEQ; }
"<="                    { return LE; }
">="                    { return GE; }
"<"                     { return LT; }
">"                     { return GT; }
"&&"                    { return AND; }
"||"                    { return OR; }
"!"                     { return NOT; }

    /* Operadores aritméticos y de asignación */
"+"                     { return PLUS; }
"-"                     { return MINUS; }
"*"                     { return MULT; }
"/"                     { return DIV; }
"="                     { return ASSIGN; }

    /* Delimitadores */
"("                     { return LPAREN; }
")"                     { return RPAREN; }
"{"                     { return LBRACE; }
"}"                     { return RBRACE; }
";"                     { return SEMI; }
","                     { return COMMA; }

    /* Literales e identificadores */
{FLOTANTE}              { yylval.dval = atof(yytext); return FLOAT_LITERAL; }
{ENTERO}                { yylval.ival = atoi(yytext); return INT_LITERAL; }
{CADENA}                { yylval.str = strdup(yytext); return STRING_LITERAL; }
{ID}                    { yylval.str = strdup(yytext); return ID; }

    /* Espacios en blanco y saltos de línea */
[ \t\r]+                { /* Ignorar espacios y tabulaciones */ }
\n                      { /* yylineno incrementa automáticamente */ }

    /* Caracteres no reconocidos */
.                       {
                            fprintf(stderr, "Error lexico en linea %d: caracter no reconocido '%s'.\n", yylineno, yytext);
                            errores_lexicos++;
                        }

%%