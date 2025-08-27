%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VarLoc 0x4000
#define VarSpace 0x5f00
#define ArgLoc 0x9f01
#define SP0 0xc0ff

#define SHORT_TYPE 0
#define CHAR_TYPE 1
#define SHORT_PTR_TYPE 2
#define CHAR_PTR_TYPE 3

#define IF_LOOP 1
#define WHILE_LOOP 2
#define FOR_LOOP 3

int yylex(void);
void yyerror(const char *s);
int yywrap(void);

FILE *out;
extern FILE *yyin;

typedef struct {
    char name[64];
    int reg;
    int addr;
    int type;
} Var;

typedef struct {
    char name[64];
    int num_arg;
    int arg_offset;
    int ret_type;
    Var arg[32];
} Func;

Var vars[VarSpace];
Func func[4096];
int var_count = 0;
int func_count = 0;
int tmp_Arg_cnt = 0;
int Arg_set = 0;
int arg_count = 0;
int tmp_reg = 8; // R8..R14 pour temporaires
int labelCount = 0; // compteur global pour labels uniques
int LineCount = 0; // compteur de ligne du code source
int TMP_pipe = 0;
char func_pipe[64];
const char Internal_Reg[11][8] = {"GPI0", "GPI1", "GPO0", "GPO1", "SPI", "CONFSPI", "UART","BAUDL", "BAUDH", "STATUS", "CONFINT"};


int test_name(const char *name){
    for (int i = 0; i < func_count; i++) {
        for (int j = 0; j < func[i].num_arg; j++) {
            if (strcmp(func[i].arg[j].name, name) == 0){
                yyerror(" Argument already exists with this name");
                return 1;
            }
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
int get_func(const char *name) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(func[i].name, name) == 0) {
            return i;
        }
    }
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
            vars[var_count].type = SHORT_TYPE;
            var_count++;
            return reg;
            break;
        case SHORT_PTR_TYPE: // SHORT []
            vars[var_count].reg = byte_lenght;
            vars[var_count].addr = addr;
            vars[var_count].type = SHORT_PTR_TYPE;
            var_count+= byte_lenght;
            return reg;
            break;
        case CHAR_TYPE: // CHAR
            vars[var_count].reg = reg;
            vars[var_count].addr = addr;
            vars[var_count].type = CHAR_TYPE;
            var_count++;
            return reg;
            break;
        case CHAR_PTR_TYPE: // CHAR []
            vars[var_count].reg = byte_lenght;
            vars[var_count].addr = addr;
            vars[var_count].type = CHAR_PTR_TYPE;
            var_count+= byte_lenght;
            return reg;
            break;
        default:
            yyerror(" Invalid variable type");
            return 0;
    }

}

int get_var_addr(const char *name, const char *func_name) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) return vars[i].addr;
    }
    int tmp = get_func(func_name);
    for (int i = 0; i < func[tmp].num_arg; i++) {
        if (strcmp(func[tmp].arg[i].name, name) == 0) return func[tmp].arg[i].addr;
    }
    yyerror(" Variable/Arg doesn't exists");
    return 0;
}

int get_var_type(const char *name, const char *func_name) {
    int tmp = get_func(func_name);
    for (int i = 0; i < func[tmp].num_arg; i++) {
        if (strcmp(func[tmp].arg[i].name, name) == 0) return func[tmp].arg[i].type;
    }
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) return vars[i].type;
    }
    yyerror(" Variable doesn't exists");
    return 0;
}

int create_arg_reg(const char *name, int type,  const char *func_name) {
    if(test_name(name)) {
        return 0;
    }
    int tmp = get_func(func_name);
    int reg = func[tmp].num_arg;
    int addr = func[tmp].arg_offset + func[tmp].num_arg;
    strncpy(func[tmp].arg[reg].name, name, sizeof(func[tmp].arg[reg].name)-1);
    func[tmp].arg[reg].name[sizeof(func[tmp].arg[reg].name)-1] = '\0';
    func[tmp].arg[reg].reg = reg;
    func[tmp].arg[reg].addr = addr;
    func[tmp].arg[reg].type = type;
    func[tmp].num_arg++;
    arg_count++;
    return reg;
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
    func[func_count].num_arg = num_args;
    func[func_count].arg_offset = arg_count+ArgLoc;
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

void convert_str_intlist(char* list, int* intlist){
    int strlen_list = strlen(list);
    char buf[32];
    int num_cnt = 0;
    int buf_cnt = 0;
    for(int i = 0;i<strlen_list;i++){
        if(list[i]==','){
            buf[buf_cnt] = '\0';
            printf("valeur buf :%d",atoi(buf));
            intlist[num_cnt]=atoi(buf);
            num_cnt++;
            buf_cnt=0;
        }else{
            buf[buf_cnt]=list[i];
            buf_cnt++;
        }
    }
    buf[buf_cnt] = '\0';
    printf("valeur buf :%d",atoi(buf));
    intlist[num_cnt]=atoi(buf);
    num_cnt++;
    intlist[num_cnt]='\0';
    for(int j = 0;j<num_cnt;j++){
        printf("\nvaleur intlist[%d] :%d\n", j,intlist[j]);
    }
}

int intstrlen(int* intlist){
    int i=0;
    while(intlist[i]!='\0')i++;
    printf("valeur i :%d",i);
    return i;
}

int label_stack[255];
int label_stack_ptr = 0;

int push_label(){
    label_stack[label_stack_ptr]=labelCount;
    label_stack_ptr++;
    labelCount++; 
    return labelCount-1;
}

int read_label(){
    return label_stack[label_stack_ptr-1];
}

int pop_label(){
    label_stack_ptr--;
    return label_stack[label_stack_ptr];
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

%type <reg> comparable_expression
%type <reg> simple_expression
%type <reg> expression
%type <str> varname
%type <str> funcname
%type <num> While
%type <num> Semicolon
%type <num> condition
%type <reg> func_call 
%type <str> func_set
%type <str> op 
%type <str> op_symetrical
%type <num> var_type_list
%type <num> var_type_var 
%type <num> var_type_ptr
%type <num> var_type
%type <num> arg_type_var
%type <num> arg_type_ptr
%type <num> arg_type
%type <str> const_list
%type <num> arguments_declaration

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
    | MUL { yyerror("Mult not implemented");$$ = "MUL"; }
    | DIV { yyerror("Div not implemented");$$ = "DIV"; }
    | SHL { $$ = "SHL"; }
    | SHR { $$ = "SHR"; }
    | BAND { $$ = "AND"; }
    | BOR { $$ = "OR"; }
    | BXOR { $$ = "XOR"; }
    ;

op_symetrical : 
    PLUS { $$ = "ADD"; }
    | MUL { yyerror("Mult not implemented");$$ = "MUL"; }
    | BAND { $$ = "AND"; }
    | BOR { $$ = "OR"; }
    | BXOR { $$ = "XOR"; }
    ;

var_type_list:
    SHORT varname LBRACKET NUMBER RBRACKET { 
        $$ = create_var_reg($2,SHORT_PTR_TYPE,$4);
    }
    | CHAR varname LBRACKET NUMBER RBRACKET { 
        $$ = create_var_reg($2,CHAR_PTR_TYPE,$4); 
    }
    ;
var_type_var: 
    SHORT varname{ $$ = create_var_reg($2,SHORT_TYPE,1); }
    | CHAR varname{ $$ = create_var_reg($2,CHAR_TYPE,1); }
    ;
var_type_ptr: 
    SHORT MUL varname{ $$ = create_var_reg($3,SHORT_PTR_TYPE,1); }
    | CHAR MUL varname{ $$ = create_var_reg($3,CHAR_PTR_TYPE,1); }
    ;
var_type:
    var_type_var{ $$ = $1; }
    | var_type_list{ $$ = $1; }
    | var_type_ptr{ $$ = $1; }
    ;

arg_type_ptr: 
    SHORT MUL varname{ $$ = create_arg_reg($3,SHORT_PTR_TYPE,func_pipe); }
    | CHAR MUL varname{ $$ = create_arg_reg($3,CHAR_PTR_TYPE,func_pipe); }
    ;
arg_type_var: 
    SHORT varname{ $$ = create_arg_reg($2,SHORT_TYPE,func_pipe); }
    | CHAR varname{ $$ = create_arg_reg($2,CHAR_TYPE,func_pipe); }
    ;
arg_type: 
    arg_type_var{ $$ = $1; }
    | arg_type_ptr{ $$ = $1; }
    ;



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
    arg_type{
        int r = $1;
        int tmp = get_func(func_pipe);
        func[tmp].num_arg=1;
        fprintf(out, " ; argument (%d) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr);
        $$ = 1;
    } 
    | arguments_declaration COMMA arg_type
    {
        int r = $3;
        int tmp = get_func(func_pipe);
        fprintf(out, " ; argument (%d) %s addr=0x%04x\n", func[tmp].arg[r].type, func[tmp].arg[r].name, func[tmp].arg[r].addr);
        $$ = $3+1;
    } 
    ;

arguments:
    expression {
        int tmp = get_func(func_pipe);
        fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$1 ,func[tmp].arg[Arg_set].addr, Arg_set);
        Arg_set=1;
    }
    | arguments COMMA expression {
        int tmp = get_func(func_pipe);
        fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$3 ,func[tmp].arg[Arg_set].addr, Arg_set);
        Arg_set++;
    }
    ;

func_set:
    VOID funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2,0);
        $$ = $2;
    }      
    | SHORT funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2,0);
        $$ = $2;
    }
    ;

funcdeclaration:
    func_set LPAREN RPAREN LBRACE program RBRACE{
    }
    | func_set LPAREN arguments_declaration RPAREN LBRACE program RBRACE{
    }
    ;

func_call:
    funcname LPAREN RPAREN{
        int tmp = get_func($1);
        int num_arg = func[get_func($1)].num_arg;
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
        int tmp = get_func($1);
        int num_arg = func[get_func($1)].num_arg;
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
        int len = snprintf(NULL, 0, "%d", $1);  // taille nécessaire (sans \0)
        char *str = malloc(len + 1);
        sprintf(str, "%d", $1);
        $$ = str;
    }
    | const_list COMMA NUMBER {
        int len = snprintf(NULL, 0, "%d", $3);  // taille nécessaire (sans \0)
        char *str = malloc(len + 2);
        sprintf(str, "%s,%d",$1 ,$3);
        $$ = str;
    }
    ;

declaration:
    var_type_list ASSIGN LBRACE const_list RBRACE
    {
        int varname = $1;
        int ad = vars[varname].addr;
        int r = new_tmp();
        int num_list[strlen($4)];
        convert_str_intlist($4,num_list);
        if(intstrlen(num_list)>vars[varname].reg)yyerror("Array size mismatch");
        for(int i=0; i<intstrlen(num_list); i++) {
            fprintf(out, "LOAD R%d %d ; %s[%d] <- %d\n", r,num_list[i], vars[varname].name, i, num_list[i]);
            fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i);
        }
        free($4);
    }
    | var_type_list ASSIGN STRING
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
    | var_type_ptr ASSIGN BAND varname
    {
        int ad_ptr = vars[$1].addr;
        int ad_var = get_var_addr($4,0);
        int r = new_tmp();
        fprintf(out, "LOAD R%d 0x%04x ; %s <- &%s\n", r, ad_var, vars[$1].name, $4);
        fprintf(out, "OUTI R%d 0x%04x\n",r, ad_ptr);
    }
    | var_type ASSIGN expression
    {
        int ad = vars[$1].addr;
        fprintf(out, "OUTI R%d 0x%04x ; déclaration %s addr=0x%04x\n", $3, ad, vars[$1].name, ad);
    }
    | var_type
    {
        int r = $1;
        int ad = vars[r].addr;
        fprintf(out, ";  déclaration %s addr=0x%04x\n", vars[r].name, ad);
    }
    ;

assignment:
    varname ASSIGN BAND varname
    {
        int tmp = get_reg_addr($1);
        int r = new_tmp();
        if (tmp != -1) {
            yyerror("internal reg are not of type ptr");
        } else {
            int ad_ptr = get_var_addr($1,func_pipe);
            int ad_var = get_var_addr($4,func_pipe);
            fprintf(out, "LOAD R%d 0x%04x ; %s <- &%s\n", r, ad_var, $1, $4);
            fprintf(out, "OUTI R%d 0x%04x", r, ad_ptr);
        }
        free($1);
    }
    | varname ASSIGN expression
    {
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", $3, tmp, $1, $3);
        } else {
            int ad = get_var_addr($1,func_pipe);
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
            int ad = get_var_addr($1,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            fprintf(out, "%s R%d R%d R%d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, ad, $1, r);
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
            int ad = get_var_addr($1,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            fprintf(out, "%sI R%d R%d %d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, ad, $1, r);
        }
        free($1);
    }
    | varname PLUS PLUS
    {
        int r = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
        fprintf(out, "ADDI R%d R%d 1\n", r, r);
        fprintf(out, "OUTI R%d 0x%04x ; %s <- %s+1\n", r, ad, $1, $1);
        free($1);
    }
    | varname MINUS MINUS
    {
        int r = new_tmp();
        int ad = get_var_addr($1,func_pipe);
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
            if(get_var_type($1,func_pipe)==CHAR_PTR_TYPE || get_var_type($1,func_pipe)==SHORT_PTR_TYPE){
                int ad = get_var_addr($1,func_pipe);
                int r = new_tmp();
                fprintf(out, "INI R%d 0x%04x ; %s[%d] <- R%d\n", r, ad, $1, $3, $6);
                fprintf(out, "ADDI R%d R%d %d\n", r, r, $3);
                fprintf(out, "OUT R%d R%d\n", $6, r);
            }else{
                int ad = get_var_addr($1,func_pipe);
                fprintf(out, "OUTI R%d 0x%04x ; %s[%d] <- R%d\n",$6, ad+$3, $1, $3, $6);
            }
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
            if(get_var_type($1,func_pipe)==CHAR_PTR_TYPE || get_var_type($1,func_pipe)==SHORT_PTR_TYPE){
                int ad = get_var_addr($1,func_pipe);
                int r = new_tmp();
                fprintf(out, "INI R%d 0x%04x ; %s[%d] <- R%d\n", r, ad, $1, $3, $6);
                fprintf(out, "ADD R%d R%d R%d\n", r, r, $3);
                fprintf(out, "OUT R%d R%d\n", $6, r);
            }else{
                int ad = get_var_addr($1,func_pipe);
                int r = new_tmp();
                fprintf(out, "ADDI R%d R%d %d\n",r, $3, ad);
                fprintf(out, "OUT R%d R%d ; %s[%d] <- R%d\n",$6, r, $1, $3, $6);
            }
        }
        free($1);
    }
    ;
expression:
    comparable_expression { $$ = $1; }
    | simple_expression { $$ = $1; }
    ;
comparable_expression:
    expression op NUMBER
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
    ;

simple_expression :
    func_call
    | varname LBRACKET NUMBER RBRACKET
    {
        int r = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        fprintf(out, "INI R%d 0x%04x\n", r, ad);
        fprintf(out, "ADDI R%d R%d %d\n", r, r, $3);
        fprintf(out, "IN R%d R%d ; lecture %s[%d] -> R%d\n", r, r, $1, $3, r);
        $$ = r;
        free($1);
    }
    | varname LBRACKET expression RBRACKET
    {
        int r = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        fprintf(out, "INI R%d 0x%04x\n", r, ad);
        fprintf(out, "ADD R%d R%d R%d\n", r, r, $3);
        fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r, r, $1, $3, r);
        $$ = r;
        free($1);
    }
    | varname
    {
        int tmp = get_reg_addr($1);
        int r = new_tmp();
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, tmp, $1, r);
            $$ = r;
        } else {
            int vartype = get_var_type($1,func_pipe);
            int ad = get_var_addr($1,func_pipe);
            if(vartype == CHAR_PTR_TYPE || vartype == SHORT_PTR_TYPE){
                fprintf(out, "LOAD R%d 0x%04x ; lecture &%s -> %d\n", r, ad, $1, r);
            }else{
                fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
            }
            $$ = r;
        }
        free($1);
    }
    | BAND varname
    {
        int r = new_tmp();
        int ad = get_var_addr($2,func_pipe);
        fprintf(out, "LOAD R%d 0x%04x ; lecture &%s -> %d\n", r, ad, $2, r);
        $$ = r;
        free($2);
    }
    | MINUS NUMBER
    {
        unsigned short tmp = -$2;
        int r = new_tmp();
        fprintf(out, "LOAD R%d %d\n", r, tmp);
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
        TMP_pipe =  read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition ==\n", r, $1, $3);
        fprintf(out,"JM0 if_%04d\n", TMP_pipe);      // Si égal (0), aller à if
        fprintf(out,"JMP else_if_%04d\n", TMP_pipe);   // Sinon, aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);
        $$ = TMP_pipe;
    }
    | expression NE expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition !=\n", r, $1, $3);
        fprintf(out,"JM0 else_if_%04d\n", TMP_pipe);   // Si égal (0), aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);       // Sinon, aller à if
        $$ = TMP_pipe;
    }
    | expression LE expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition <=\n", r, $3, $1);
        fprintf(out,"JMN else_if_%04d\n", TMP_pipe);       // Si négatif, aller à if
        fprintf(out,"if_%04d :\n", TMP_pipe);   // Si positif, aller à end_if
        $$ = TMP_pipe;
    }
    | expression GE expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition >=\n", r, $1, $3);  // CORRIGÉ: $1 - $3
        fprintf(out,"JMN else_if_%04d\n", TMP_pipe);   // Si négatif, aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);       // Si positif, aller à if
        $$ = TMP_pipe;
    }
    | expression LT expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition <\n", r, $1, $3);
        fprintf(out,"JMN if_%04d\n", TMP_pipe);       // Si négatif, aller à if
        fprintf(out,"JMP else_if_%04d\n", TMP_pipe);   // Sinon (>=0), aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);
        $$ = TMP_pipe;
    }
    | expression GT expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition >\n", r, $3, $1);   // CORRIGÉ: $1 - $3
        fprintf(out,"JMN if_%04d\n", TMP_pipe);   // Si négatif, aller à end_if
        fprintf(out,"JMP else_if_%04d\n", TMP_pipe);       // Si positif, aller à if
        fprintf(out,"if_%04d :\n", TMP_pipe);
        $$ = TMP_pipe;
    }
    | comparable_expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"JM0 else_if_%04d ; condition != 0\n", TMP_pipe);      // Si égal (0), aller à if
        fprintf(out,"if_%04d :\n", TMP_pipe);           // Sinon, aller à end_if
        $$ = TMP_pipe;
    }
    | simple_expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUBI R%d R%d 0 ; condition != 0\n", r, $1);
        fprintf(out,"JM0 else_if_%04d\n", TMP_pipe);      // Si égal (0), aller à if
        fprintf(out,"if_%04d :\n", TMP_pipe);           // Sinon, aller à end_if
        $$ = TMP_pipe;
    }
    ;

Else:
    ELSE
    {
        fprintf(out,"JMP end_if_%04d\n", read_label());
        fprintf(out,"else_if_%04d :\n", read_label());
    }
    ;

If:
    IF
    {
        push_label();
    }
    ;

if_statement:
    If LPAREN condition RPAREN statement Else statement
    {
        fprintf(out,"end_if_%04d :\n", pop_label());
    }
    | If LPAREN condition RPAREN statement
    {
        fprintf(out,"else_if_%04d :\n", pop_label());
    }
    ;

While:
    WHILE
    {
        int tmp = push_label();
        fprintf(out,"while_%04d :\n", tmp);
        $$ = tmp;
    }
    ;

while_statement:
    While LPAREN condition RPAREN statement
    {
        int tmp = pop_label();
        fprintf(out,"JMP while_%04d\n", tmp);
        fprintf(out,"else_if_%04d :\n", tmp);
    }
    ;

Semicolon:
    SEMICOLON
    {
        int tmp = push_label();
        fprintf(out,"for_%04d :\n", tmp);
        $$ = tmp;
    }
    ;

for_statement:
    FOR LPAREN declaration Semicolon condition SEMICOLON assignment RPAREN statement
    {
        int tmp = pop_label();
        fprintf(out,"JMP for_%04d\n", pop_label());
        fprintf(out,"else_if_%04d :\n", tmp);
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
        strcpy(func_pipe,$1);
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
    printf("\nTaille de la Ram : %d/%d (%.2f%%) Half Words\n",var_count,VarSpace,((float)var_count*100/VarSpace));
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