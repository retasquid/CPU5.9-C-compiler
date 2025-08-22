%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VarLoc 0x4000
#define VarSpace 0x5f00
#define ArgLoc 0x9f01
#define SP0 0xc0ff

#define SHORT_TYPE 0
#define SHORT_ARRAY_TYPE 1
#define CHAR_TYPE 2
#define CHAR_ARRAY_TYPE 3

int yylex(void);
void yyerror(const char *s);
int yywrap(void);

FILE *out;
extern FILE *yyin;

typedef struct {
    char name[64];
    int reg;
    int addr;
} Var;

Var vars[VarSpace];
Var arg[254];
Var func[4096];
int var_count = 0;
int arg_count = 0;
int func_count = 0;
int tmp_reg = 8; // R8..R14 pour temporaires
int labelCount = 0; // compteur global pour labels uniques
int LineCount = 0; // compteur de ligne du code source
int Arg_set = 0;
const char Internal_Reg[11][8] = {"GPI0", "GPI1", "GPO0", "GPO1", "SPI", "CONFSPI", "UART","BAUDL", "BAUDH", "STATUS", "CONFINT"};


int test_name(const char *name){
    for (int i = 0; i < arg_count; i++) {
          if (strcmp(arg[i].name, name) == 0){
              yyerror(" Argument already exists with this name");
            return 1;
          }
        }
    for (int j = 0; j < var_count; j++) {
        if (strcmp(vars[j].name, name) == 0){
            yyerror(" Variable already exists with this name");
            return 1;
        }
    }
    return 0; // Nom valide, pas de conflit
}

int get_var_reg(const char *name) {
    for (int i = 0; i < arg_count; i++) {
        if (strcmp(arg[i].name, name) == 0) {
            return arg[i].reg;
        }
    }
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) {
            return vars[i].reg;
        }
    }
    yyerror(" Variable/Argument doesn't exists");
    return 0;
}


int create_var_reg(const char *name, short type, int byte_lenght) {
    if(test_name(name)) {
        return 0;
    }
    if (var_count >= VarSpace) {
        yyerror(" Variable limit reached, RAM full");
        return 0;
    }
    int reg = var_count;
    int addr = VarLoc + var_count;
    strncpy(vars[var_count].name, name, sizeof(vars[var_count].name)-1);
    vars[var_count].name[sizeof(vars[var_count].name)-1] = '\0';

    switch (type) {
        case SHORT_TYPE: // SHORT
            vars[var_count].reg = reg;
            vars[var_count].addr = addr;
            var_count++;
            return reg;
            break;
        case SHORT_ARRAY_TYPE: // SHORT []
            vars[var_count].reg = byte_lenght;
            vars[var_count].addr = addr;
            var_count+= byte_lenght;
            return reg;
            break;
        case CHAR_TYPE: // CHAR
            vars[var_count].reg = reg;
            vars[var_count].addr = addr;
            var_count++;
            return reg;
            break;
        case CHAR_ARRAY_TYPE: // CHAR []
            vars[var_count].reg = byte_lenght;
            vars[var_count].addr = addr;
            var_count+= byte_lenght;
            return reg;
            break;
        default:
            yyerror(" Invalid variable type");
            return 0;
    }

}

int get_var_addr(const char *name) {
    for (int i = 0; i < arg_count; i++) {
        if (strcmp(arg[i].name, name) == 0) return arg[i].addr;
    }
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) return vars[i].addr;
    }
    yyerror(" Variable doesn't exists");
    return 0;
}

int create_arg_reg(const char *name) {
    if(test_name(name)) {
        return 0;
    }
    int reg = arg_count;
    int addr = ArgLoc + arg_count;
    strncpy(arg[arg_count].name, name, sizeof(arg[arg_count].name)-1);
    arg[arg_count].name[sizeof(arg[arg_count].name)-1] = '\0';
    arg[arg_count].reg = reg;
    arg[arg_count].addr = addr;
    arg_count++;
    return reg;
}

void clear_arg(){
  for(int i=0; i<arg_count; i++){
    arg[i].name[0] = '\0';
    arg[i].reg = 0;
    arg[i].addr = 0;
  }
}

int get_func(const char *name) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(func[i].name, name) == 0) {
            return func[i].reg;
        }
    }
    yyerror(" Function doesn't exists");
    return 0;
}

void create_func(const char *name, int num_args) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(func[i].name, name) == 0){
            yyerror(" Function already exists");
            return;
        }
    }
    int reg = func_count;
    strncpy(func[func_count].name, name, sizeof(func[func_count].name)-1);
    func[func_count].name[sizeof(func[func_count].name)-1] = '\0';
    func[func_count].reg = num_args;
    func_count++;
}

int new_tmp() {
    if (tmp_reg > 14) tmp_reg = 8;
    return tmp_reg++;
}

int get_reg_addr(const char* name) {
    for (int i = 0; i < 11; i++) {
        if (strcmp(name, Internal_Reg[i]) == 0)return i;
    }
    return -1;
}

%}

%union {
    int num;
    char *str;
    int reg; /* registre où se trouve le résultat */
}

%token <num> NUMBER
%token <str> IDENT
%token <str> STRING

%token VOID SHORT CHAR IF ELSE WHILE FOR RETURN
%token EQ NE LE GE LT GT
%token PLUS MINUS MUL DIV SHL SHR BAND BOR BXOR BNOT
%token ASSIGN
%token GPI0 GPI1 GPO0 GPO1 SPI CONFSPI UART BAUDL BAUDH STATUS CONFINT
%token LPAREN RPAREN LBRACE RBRACE SEMICOLON COMMA LCOMMENT RCOMMENT LBRACKET RBRACKET QUOTE

%type <reg> expression 
%type <str> varname
%type <str> funcname
%type <num> While
%type <num> For
%type <num> condition
%type <reg> func_call
%type <str> op 
%type <str> op_symetrical
%type <num> var_type_list
%type <num> var_type_var
%type <num> var_type
//%type <num> arg_type_list
%type <num> arg_type_var
//%type <num> arg_type
%type <str> const_list
%type <str> list_expression

%left BOR
%left BXOR
%left BAND
%left EQ NE
%left LT LE GT GE
%left SHL SHR
%left PLUS MINUS
%left MUL DIV
%left ELSE
%right BNOT
%start program

%%
op: 
    PLUS { $$ = "ADD"; }
    | MINUS { $$ = "SUB"; }
    | MUL { $$ = "MUL"; }
    | DIV { $$ = "DIV"; }
    | SHL { $$ = "SHL"; }
    | SHR { $$ = "SHR"; }
    | BAND { $$ = "AND"; }
    | BOR { $$ = "OR"; }
    | BXOR { $$ = "XOR"; }
    ;

op_symetrical : 
    PLUS { $$ = "ADD"; }
    | MUL { $$ = "MUL"; }
    | BAND { $$ = "AND"; }
    | BOR { $$ = "OR"; }
    | BXOR { $$ = "XOR"; }
    ;

var_type_list:
    SHORT varname LBRACKET NUMBER RBRACKET { 
        $$ = create_var_reg($2,SHORT_ARRAY_TYPE,$4);
    }
    | CHAR varname LBRACKET NUMBER RBRACKET { 
        $$ = create_var_reg($2,CHAR_ARRAY_TYPE,$4); 
    }
    ;
var_type_var: 
    SHORT varname{ $$ = create_var_reg($2,SHORT_TYPE,1); }
    | CHAR varname{ $$ = create_var_reg($2,CHAR_TYPE,1); }
    ;
var_type:
    var_type_var{ $$ = $1; }
    | var_type_list{ $$ = $1; }
    ;

/*arg_type_list:
    SHORT varname LBRACKET NUMBER RBRACKET { 
        $$ = create_arg_reg($2);
    }
    | CHAR varname LBRACKET NUMBER RBRACKET { 
        $$ = create_arg_reg($2); 
    }
    ;*/
arg_type_var: 
    SHORT varname{ $$ = create_arg_reg($2); }
    | CHAR varname{ $$ = create_arg_reg($2); }
    ;
/*arg_type :
    arg_type_var{ $$ = $1; }
    | arg_type_list{ $$ = $1; }
    ;*/

program:
    /* empty */
  | program element
  ;

element:
    funcdeclaration 
  | statement
  ;

statement_list:
    /* vide */
    | statement_list statement
    ;

arguments_declaration:
    arg_type_var
    {
        int r = $1;
        int ad = arg[r].addr;
        fprintf(out, " ; argument %s addr=0x%04x\n", arg[r].name, ad);
    } 
    | arguments_declaration COMMA arg_type_var
    {
        int r = $3;
        int ad = arg[r].addr;
        fprintf(out, " ; argument %s addr=0x%04x\n", arg[r].name, ad);
    } 
    ;

arguments:
    expression {
        fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$1 ,ArgLoc+Arg_set, Arg_set);
        Arg_set++;
    }
    | arguments COMMA expression {
        fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$3 ,ArgLoc+Arg_set, Arg_set);
        Arg_set++;
    }
    ;

func_set:
    VOID funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2, 0);
    }      
    | SHORT funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2, 0);
    }
    ;

funcdeclaration:
    func_set LPAREN RPAREN LBRACE program RBRACE{
    }
    | func_set LPAREN arguments_declaration RPAREN LBRACE program RBRACE{
        // Mettre à jour le nombre d'arguments de la fonction
        if(func_count > 0) {
            func[func_count-1].reg = arg_count;
        }
        clear_arg();
        arg_count = 0;
    }
    ;

func_call:
    funcname LPAREN RPAREN{
        int num_arg = get_func($1);
        int r = new_tmp();
        fprintf(out, "CALL ; appel de %s\n", $1);
        fprintf(out, "SUBI SP SP 1\n");
        fprintf(out, "JMP %s\n", $1);
        fprintf(out, "INI R%d 0x%x\n",r,ArgLoc-1);
        if(Arg_set != 0){
            yyerror("Function called with wrong number of arguments");
        }
        Arg_set = 0;
        free($1);
        $$ = r;
    }
    | funcname LPAREN arguments RPAREN{
        int num_arg = get_func($1);
        int r = new_tmp();
        fprintf(out, "CALL ; appel de %s\n", $1);
        fprintf(out, "SUBI SP SP 1\n");
        fprintf(out, "JMP %s\n", $1);
        fprintf(out, "INI R%d 0x%x\n",r,ArgLoc-1);
        if(Arg_set != num_arg){
            yyerror("Function called with wrong number of arguments");
        }
        Arg_set = 0;
        free($1);
        $$ = r;
    }
    ;

statement: 
    LBRACE statement_list RBRACE
    | if_statement
    | while_statement
    | for_statement
    | declaration SEMICOLON
    | assignment SEMICOLON
    | func_call SEMICOLON
    | RETURN expression SEMICOLON{
        fprintf(out, "OUTI R%d 0x%04x\nADDI SP SP 1 ;return\nRET\n",$2,ArgLoc-1);
    }
    ;

const_list:
    NUMBER{
        char *str = malloc(2);
        sprintf(str, "%d", $1);
        $$ = str;
    }
    | const_list COMMA NUMBER {
        char *str = malloc(strlen($1) + 2);
        sprintf(str, "%s%d", $1, $3);
        free($1);
        $$ = str;
    }
    ;

list_expression:
    LBRACE const_list RBRACE{
        $$ = $2;
    }
    | STRING{
        $$ = $1;
    }
    ;

declaration:
    var_type_list ASSIGN list_expression
    {
        int varname = $1;
        int ad = vars[varname].addr;
        int r = new_tmp();
        if(strlen($3)>vars[varname].reg)yyerror("Array size mismatch");
        for(int i=0; i<strlen($3); i++) {
            fprintf(out, "LOAD R%d %d ; %s[%d] <- %d\n", r,$3[i], vars[varname].name, i, $3[i]);
            fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i);
        }
    }
    | var_type_var ASSIGN expression
    {
        int r = $1;
        int ad = vars[r].addr;
        fprintf(out, "OUTI R%d 0x%04x ; déclaration %s addr=0x%04x\n", $3, ad, vars[r].name, ad);
    }
    | var_type_list ASSIGN expression
    {
        int varname = $1;
        int ad = vars[varname].addr;
        fprintf(out, "OUTI R%d 0x%04x\n", $3, ad);
    }
    | var_type
    {
        int r = $1;
        int ad = vars[r].addr;
        fprintf(out, ";  déclaration %s addr=0x%04x\n", vars[r].name, ad);
    }
    ;

assignment:
    varname ASSIGN expression
    {
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", $3, tmp, $1, $3);
        } else {
            int ad = get_var_addr($1);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", $3, ad, $1, $3);
        }
        free($1);
    }
    | varname op ASSIGN expression
    {
        int r = new_tmp();
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $1, r);
            fprintf(out, "%s R%d R%d R%d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, tmp, $1, r); 
        } else {
            int ad = get_var_addr($1);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            fprintf(out, "%s R%d R%d R%d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", $4, ad, $1, $4);
        }
        free($1);
    }
    | varname op ASSIGN NUMBER
    {
        int r = new_tmp();
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $1, r);
            fprintf(out, "%sI R%d R%d %d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, tmp, $1, r); 
        } else {
            int ad = get_var_addr($1);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            fprintf(out, "%sI R%d R%d %d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", $4, ad, $1, $4);
        }
        free($1);
    }
    | varname PLUS PLUS
    {
        int r = new_tmp();
        int ad = get_var_addr($1);
        fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
        fprintf(out, "ADDI R%d R%d 1\n", r, r);
        fprintf(out, "OUTI R%d 0x%04x ; %s <- %s+1\n", r, ad, $1, $1);
        free($1);
    }
    | varname MINUS MINUS
    {
        int r = new_tmp();
        int ad = get_var_addr($1);
        fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
        fprintf(out, "SUBI R%d R%d 1\n", r, r);
        fprintf(out, "OUTI R%d 0x%04x ; %s <- %s-1\n", r, ad, $1, $1);
        free($1);
    }
    | varname LBRACKET NUMBER RBRACKET ASSIGN expression
    {
        char *var_name;
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            sprintf(var_name," Register %s already exists with this name",$1);
            yyerror(var_name);
        }else {
            int ad = get_var_addr($1);
            fprintf(out, "OUTI R%d 0x%04x ; %s[%d] <- R%d\n",$6, ad+$3, $1, $3, $6);
        }
        free($1);
    }
    | varname LBRACKET expression RBRACKET ASSIGN expression
    {
        char *var_name;
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            sprintf(var_name," Register %s already exists with this name",$1);
            yyerror(var_name);
        } else {
            int ad = get_var_addr($1);
            int r = new_tmp();
            fprintf(out, "ADDI R%d R%d 0x%04x\n",r, $3, ad);
            fprintf(out, "OUT R%d R%d ; %s[%d] <- R%d\n",$6, r, $1, $3, $6);
        }
        free($1);
    }
    ;

expression:
    func_call
    | varname LBRACKET NUMBER RBRACKET
    {
        int r = new_tmp();
        int ad = get_var_addr($1);
        fprintf(out, "INI R%d 0x%04x ; lecture %s[%d] -> R%d\n", r, ad+$3, $1, $3, r);
        $$ = r;
        free($1);
    }
    | varname LBRACKET expression RBRACKET
    {
        int r = new_tmp();
        int ad = get_var_addr($1);
        fprintf(out, "ADDI R%d R%d 0x%04x\n", r, $3, ad);
        fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r,r, $1, $3, r);
        $$ = r;
        free($1);
    }
    | varname
    {
        if (strcmp($1, "GPI0") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0000 ; lecture GPI0 -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "GPI1") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0001 ; lecture GPI1 -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "GPO0") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0002 ; lecture GPO0 -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "GPO1") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0003 ; lecture GPO1 -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "SPI") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0004 ; lecture SPI -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "CONFSPI") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0005 ; lecture CONFSPI -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "UART") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0006 ; lecture UART -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "BAUDL") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0007 ; lecture BAUDL -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "BAUDH") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0008 ; lecture BAUDH -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "STATUS") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x0009 ; lecture STATUS -> R%d\n", r, r);
            $$ = r;
        } else if (strcmp($1, "CONFINT") == 0) {
            int r = new_tmp();
            fprintf(out, "INI R%d 0x000a ; lecture CONFINT -> R%d\n", r, r);
            $$ = r;
        } else {
            int r = new_tmp();
            int ad = get_var_addr($1);
            fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
            $$ = r;
        }
        free($1);
    }
    | expression op NUMBER
    {
        int r = new_tmp();
        fprintf(out, "%sI R%d R%d %d\n",$2 , r, $1, $3);
        $$ = r;
    }
    | NUMBER op_symetrical expression
    {
        int r = new_tmp();
        fprintf(out, "%sI R%d R%d %d\n",$2 , r, $3, $1);
        $$ = r;
    }
    | expression op expression
    {
        int r = new_tmp();
        fprintf(out, "%s R%d R%d R%d\n",$2 , r, $1, $3);
        $$ = r;
    }
    | BNOT LPAREN expression BAND NUMBER RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NANDI R%d R%d %d\n", r, $3, $5);
        $$ = r;
    }
    | BNOT LPAREN NUMBER BAND expression RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NANDI R%d R%d %d\n", r, $5, $3);
        $$ = r;
    }
    | BNOT LPAREN expression BAND expression RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NAND R%d R%d R%d\n", r, $3, $5);
        $$ = r;
    }
    | BNOT expression
    {
        int r = new_tmp();
        fprintf(out, "NAND R%d R%d R%d\n", r, $2, $2);
        $$ = r;
    }
    | MINUS expression
    {
        int r = new_tmp();
        fprintf(out, "LOAD R%d 0\n", r);
        fprintf(out, "SUB R%d R%d R%d\n", r, r, $2);
        $$ = r;
    }
    | MINUS NUMBER
    {
        int r = new_tmp();
        fprintf(out, "LOAD R%d 0\n", r);
        fprintf(out, "SUBI R%d R%d %d\n", r, r, $2);
        $$ = r;
    }
    | LPAREN expression RPAREN
    {
        $$ = $2;
    }
    | NUMBER
    {
        int r = new_tmp();
        fprintf(out, "LOAD R%d %d\n", r, $1);
        $$ = r;
    }
    ;

condition:
    expression EQ expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition ==\n", r, $1, $3);
        fprintf(out,"JM0 if_%04d\n", thisLabel);      // Si égal (0), aller à if
        fprintf(out,"JMP else_if_%04d\n", thisLabel);   // Sinon, aller à end_if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    | expression NE expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition !=\n", r, $1, $3);
        fprintf(out,"JM0 else_if_%04d\n", thisLabel);   // Si égal (0), aller à end_if
        fprintf(out,"JMP if_%04d\n", thisLabel);       // Sinon, aller à if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    | expression LE expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition <=\n", r, $3, $1);
        fprintf(out,"JMN else_if_%04d\n", thisLabel);       // Si négatif, aller à if
        fprintf(out,"JMP if_%04d\n", thisLabel);   // Si positif, aller à end_if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    | expression GE expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition >=\n", r, $1, $3);  // CORRIGÉ: $1 - $3
        fprintf(out,"JMN else_if_%04d\n", thisLabel);   // Si négatif, aller à end_if
        fprintf(out,"JMP if_%04d\n", thisLabel);       // Si positif, aller à if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    | expression LT expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition <\n", r, $1, $3);
        fprintf(out,"JMN if_%04d\n", thisLabel);       // Si négatif, aller à if
        fprintf(out,"JMP else_if_%04d\n", thisLabel);   // Sinon (>=0), aller à end_if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    | expression GT expression
    {
        int r = new_tmp();
        int thisLabel = labelCount++;
        fprintf(out,"SUB R%d R%d R%d ; condition >\n", r, $3, $1);   // CORRIGÉ: $1 - $3
        fprintf(out,"JMN if_%04d\n", thisLabel);   // Si négatif, aller à end_if
        fprintf(out,"JMP else_if_%04d\n", thisLabel);       // Si positif, aller à if
        fprintf(out,"if_%04d :\n", thisLabel);
        $$ = thisLabel;
    }
    ;

Else:
    ELSE
    {
        fprintf(out,"JMP end_if_%04d\n", labelCount-1);
        fprintf(out,"else_if_%04d :\n", labelCount-1);
    }
    ;

if_statement:
    IF LPAREN condition RPAREN statement Else statement
    {
        fprintf(out,"end_if_%04d :\n", $3);
    }
    | IF LPAREN condition RPAREN statement
    {
        fprintf(out,"else_if_%04d :\n", $3);
    }
    ;

While:
    WHILE
    {
        fprintf(out,"while_%04d :\n", labelCount);
        $$ = labelCount;
        labelCount++;
    }
    ;

while_statement:
    While LPAREN condition RPAREN statement
    {
        fprintf(out,"JMP while_%04d\n", $1);
        fprintf(out,"else_if_%04d :\n", $1+1);
    }
    ;

For:
    FOR
    {
        fprintf(out,"for_%04d :\n", labelCount+1);
        $$ = labelCount;
    }
    ;

for_statement:
    For LPAREN declaration SEMICOLON condition SEMICOLON assignment RPAREN statement
    {
        fprintf(out,"JMP for_%04d\n", labelCount);
        fprintf(out,"else_if_%04d :\n", labelCount-1);
    }
    ;

varname:
    IDENT          { $$ = strdup($1); }
    | GPI0         { $$ = strdup("GPI0"); }
    | GPI1         { $$ = strdup("GPI1"); }
    | GPO0         { $$ = strdup("GPO0"); }
    | GPO1         { $$ = strdup("GPO1"); }
    | SPI          { $$ = strdup("SPI"); }
    | CONFSPI      { $$ = strdup("CONFSPI"); }
    | UART         { $$ = strdup("UART"); }
    | BAUDL        { $$ = strdup("BAUDL"); }
    | BAUDH        { $$ = strdup("BAUDH"); }
    | STATUS       { $$ = strdup("STATUS"); }
    | CONFINT      { $$ = strdup("CONFINT"); }
    ;


funcname:
    IDENT {
        $$ = strdup($1); 
    }
    ;

%%

int main(int argc, char *argv[]) {
    char *outfile = "main.asm"; // valeur par défaut
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erreur ouverture input");
        return 1;
    }
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            outfile = argv[i + 1];
            i++;
        }
    }
    out = fopen(outfile, "w");
    printf("\nCompilation de %s en cours\n",argv[1]);
    if (!out) { perror("../main.asm"); exit(1); }
    fprintf(out, ";   -- Code generated by CPU5.9 custom Compiler --\n");
    fprintf(out, "LOAD SP 0xc0ff\n");
    fprintf(out, "JMP main\n");
    yyparse();
    printf("\nCompilation de %s terminée avec succes\n",argv[1]);
    fclose(yyin);
    fclose(out);
    return 0;
}

void yyerror(const char* const message) {
    fprintf(stderr, "Parse error:%s\n", message);
    fprintf(stderr, "Line %d\n", LineCount);
    exit(1);
}

int yywrap(void) {
    return 1;
}