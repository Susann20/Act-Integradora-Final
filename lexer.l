%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"
#include "tabla_simbolos.h"

int linea = 1;
void contar_error_lexico() { errores_lexicos++; }
%}

%option noyywrap yylineno

%%
[ \t]+          { /* Ignorar espacios y tabs */ }
\n              { linea++; }
"//".*          { /* Comentario de una línea */ }
"/*"([^*]|\*+[^*/])*\*+"/" { /* Comentario multilínea */ }

"#include"      { return INCLUDE; }
"#define"       { return DEFINE; }
"<"[a-zA-Z0-9_.]+".h"">" { yylval.str = strdup(yytext); return LIB; }

"const"         { return CONST; }
"int"           { yylval.tipo = TIPO_INT; return TIPO; }
"double"        { yylval.tipo = TIPO_DOUBLE; return TIPO; }
"void"          { yylval.tipo = TIPO_VOID; return TIPO; }
"main"          { return MAIN; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }
"for"           { return FOR; }
"return"        { return RETURN; }
"printf"        { yylval.str = strdup(yytext); return ID; }

"=="            { return EQ; }
"!="            { return NE; }
"<="            { return LE; }
">="            { return GE; }
"&&"            { return AND; }
"||"            { return OR; }
"<"             { return LT; }
">"             { return GT; }
"!"             { return NOT; }

"="             { return ASIGN; }
"+"             { return MAS; }
"-"             { return MENOS; }
"*"             { return POR; }
"/"             { return DIV; }

"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
";"             { return PUNTO_COMA; }
","             { return COMA; }

[0-9]+\.[0-9]+  { yylval.dval = atof(yytext); return LIT_DOUBLE; }
[0-9]+          { yylval.ival = atoi(yytext); return LIT_INT; }
\"([^\"\\]|\\.)*\" { yylval.str = strdup(yytext); return LIT_STRING; }

[a-zA-Z_][a-zA-Z0-9_]* { yylval.str = strdup(yytext); return ID; }

.               { printf("Error léxico en línea %d: carácter no reconocido '%s'\n", yylineno, yytext); contar_error_lexico(); }
%%