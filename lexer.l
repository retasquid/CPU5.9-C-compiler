%{
#include "parser.tab.h"
#include "str_process.h" 
#include <stdlib.h>
#include <string.h>
%}

%%
"void"       { return VOID; }
"short"      { return SHORT; }
"char"      { return CHAR; }
"int"      { return SHORT; }
"return"     { return RETURN; }
"if"         { return IF; }
"else"       { return ELSE; }
"while"      { return WHILE; }
"for"        { return FOR; }
"GPI0"        { return GPI0; }
"GPI1"        { return GPI1; }
"GPO0"        { return GPO0; }
"GPO1"        { return GPO1; }
"SPI"        { return SPI; }
"CONFSPI"        { return CONFSPI; }
"UART"        { return UART; }
"BAUDL"        { return BAUDL; }
"BAUDH"        { return BAUDH; }
"STATUS"        { return STATUS; }
"CONFINT"        { return CONFINT; }

"=="         { return EQ; }
"!="         { return NE; }
"<="         { return LE; }
">="         { return GE; }
"<"          { return LT; }
">"          { return GT; }

">>"         { return SHR; }
"<<"         { return SHL; }

"+"          { return PLUS; }
"-"          { return MINUS; }
"*"          { return MUL; }
"/"          { return DIV; }
"&"          { return BAND; }
"|"          { return BOR; }
"^"          { return BXOR; }
"~"          { return BNOT; }
"="          { return ASSIGN; }

";"          { return SEMICOLON; }
","	     { return COMMA; }
"("          { return LPAREN; }
")"          { return RPAREN; }
"{"          { return LBRACE; }
"}"          { return RBRACE; }
"["          { return LBRACKET; }
"]"          { return RBRACKET; }
\"           { return QUOTE; }

0[xX][0-9a-fA-F]+    { yylval.num = strtol(yytext, NULL, 16); return NUMBER; }
0[bB][01]+           { yylval.num = strtol(yytext+2, NULL, 2); return NUMBER; }
'.'                  { yylval.num = (int)yytext[1]; return NUMBER; }
'\\[ntr0\\']'        {yylval.num = get_escape_char(yytext[2]); return NUMBER; }
[0-9]+               { yylval.num = atoi(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str = strdup(yytext); return IDENT; }
\"([^"\\]|\\.)*\"    { yylval.str = process_escapes(yytext+1, strlen(yytext)-2); return STRING; }
[ \t\n\r]+   ;  /* ignorer espaces et retours ligne */

.            ;  /* ignorer tout autre caractère */
%%