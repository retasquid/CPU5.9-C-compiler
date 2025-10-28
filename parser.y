%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VarLoc 0x4000    //0x4000
#define VarSpace 0x3f00 //0x5f00
#define ArgLoc 0x7f02   //0x9f02
#define ArgLocMax 0x7fff//0x9fff
#define SP0 0xc0ff

#define SHORT_TYPE 0
#define LONG_TYPE 2
#define LONG_PTR_TYPE 3
#define SHORT_PTR_TYPE 4

#define UNSIGNED_SHORT_TYPE 6
#define UNSIGNED_LONG_TYPE 8
#define UNSIGNED_LONG_PTR_TYPE 9
#define UNSIGNED_SHORT_PTR_TYPE 10

#define IF_LOOP 1
#define WHILE_LOOP 2
#define FOR_LOOP 3

#define FIRST_REG 0
#define LAST_REG 14

int yylex(void);
void yyerror(const char *s);
int yywrap(void);

FILE *out;
extern FILE *yyin;

typedef struct {
    char name[64];
    char reg;
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
int tmp_reg = 0; // R0..R14 pour temporaires
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
    vars[var_count].addr = addr;
    var_count+=byte_lenght;
    switch (type) {
        case SHORT_TYPE:
            vars[reg].reg = reg;
            vars[reg].type = SHORT_TYPE;
            return reg;
        case SHORT_PTR_TYPE:
            vars[reg].reg = byte_lenght;
            vars[reg].type = SHORT_PTR_TYPE;
            return reg;
        case LONG_TYPE:
            vars[reg].reg = reg;
            vars[reg].type = LONG_TYPE;
            return reg;
        case LONG_PTR_TYPE:
            vars[reg].reg = byte_lenght;
            vars[reg].type = LONG_PTR_TYPE;
            return reg;

        case UNSIGNED_SHORT_TYPE:
            vars[reg].reg = reg;
            vars[reg].type = UNSIGNED_SHORT_TYPE;
            return reg;
        case UNSIGNED_SHORT_PTR_TYPE:
            vars[reg].reg = byte_lenght;
            vars[reg].type = UNSIGNED_SHORT_PTR_TYPE;
            return reg;
        case UNSIGNED_LONG_TYPE:
            vars[reg].reg = reg;
            vars[reg].type = UNSIGNED_LONG_TYPE;
            return reg;
        case UNSIGNED_LONG_PTR_TYPE:
            vars[reg].reg = byte_lenght;
            vars[reg].type = UNSIGNED_LONG_PTR_TYPE;
            return reg;
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

int get_var_index(const char *name, const char *func_name) {
    int tmp = get_func(func_name);
    for (int i = 0; i < func[tmp].num_arg; i++) {
        if (strcmp(func[tmp].arg[i].name, name) == 0) return i;
    }
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) return i;
    }
    yyerror(" Variable doesn't exists");
    return 0;
}

int create_arg_reg(const char *name, int type,  const char *func_name) {
    if(test_name(name)) {
        yyerror(" Arg doesn't exists");
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
    if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
        func[tmp].num_arg+=2;
        arg_count+=2;
    }else{
        func[tmp].num_arg++;
        arg_count++;
    }
    return reg;
}

void create_func(const char *name) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(func[i].name, name) == 0){
            yyerror(" Function already exists");
            return;
        }
    }
    int reg = func_count;
    strncpy(func[func_count].name, name, sizeof(func[func_count].name)-1);
    func[func_count].name[sizeof(func[func_count].name)-1] = '\0';
    func[func_count].num_arg = 0;
    func[func_count].arg_offset = arg_count+ArgLoc;
    func_count++;
}


int new_tmp() {
    if (tmp_reg > LAST_REG) tmp_reg = FIRST_REG;
    return tmp_reg++;
}

int next_tmp(int reg) {
    if (reg > LAST_REG) reg = FIRST_REG;
    return reg++;
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
            intlist[num_cnt]=atoi(buf);
            num_cnt++;
            buf_cnt=0;
        }else{
            buf[buf_cnt]=list[i];
            buf_cnt++;
        }
    }
    buf[buf_cnt] = '\0';
    intlist[num_cnt]=atoi(buf);
    num_cnt++;
    intlist[num_cnt]='\0';
}

int intstrlen(int* intlist){
    int i=0;
    while(intlist[i]!='\0')i++;
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

%token VOID SHORT CHAR LONG USIGN SIGN IF ELSE WHILE FOR RETURN
%token EQ NE LE GE LT GT
%token PLUS MINUS MUL DIV SHL SHR BAND BOR BXOR BNOT
%token ASSIGN
%token GPI0 GPI1 GPO0 GPO1 SPI CONFSPI UART BAUDL BAUDH STATUS CONFINT
%token LPAREN RPAREN LBRACE RBRACE SEMICOLON COMMA LCOMMENT RCOMMENT LBRACKET RBRACKET QUOTE
%token JMCARRY U L S

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
%type <str> var_type_list
%type <str> var_type_var 
%type <str> var_type_ptr
%type <str> var_type
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
        create_var_reg($2,SHORT_PTR_TYPE,$4);
        $$ = $2;
    }
    | LONG varname LBRACKET NUMBER RBRACKET { 
        create_var_reg($2,LONG_PTR_TYPE,$4*2); 
        $$ = $2;
    }
    | SIGN SHORT varname LBRACKET NUMBER RBRACKET { 
        create_var_reg($3,SHORT_PTR_TYPE,$5);
        $$ = $3;
    }
    | SIGN LONG varname LBRACKET NUMBER RBRACKET { 
        create_var_reg($3,LONG_PTR_TYPE,$5*2); 
        $$ = $3;
    }
    | USIGN SHORT varname LBRACKET NUMBER RBRACKET { 
        create_var_reg($3,UNSIGNED_SHORT_PTR_TYPE,$5);
        $$ = $3;
    }
    | USIGN LONG varname LBRACKET NUMBER RBRACKET { 
        create_var_reg($3,UNSIGNED_LONG_PTR_TYPE,$5*2); 
        $$ = $3;
    }
    ;
var_type_var: 
    SHORT varname{
        create_var_reg($2,SHORT_TYPE,1); 
        $$ = $2;
    }
    | LONG varname{ 
        create_var_reg($2,LONG_TYPE,2); 
        $$ = $2;
    }
    | SIGN SHORT varname{ 
        create_var_reg($3,SHORT_TYPE,1); 
        $$ = $3;
    }
    | SIGN LONG varname{ 
        create_var_reg($3,LONG_TYPE,2); 
        $$ = $3;
    }
    | USIGN SHORT varname{ 
        create_var_reg($3,UNSIGNED_SHORT_TYPE,1); 
        $$ = $3;
    }
    | USIGN LONG varname{ 
        create_var_reg($3,UNSIGNED_LONG_TYPE,2); 
        $$ = $3;
    }
    ;
var_type_ptr: 
    SHORT MUL varname{ 
        create_var_reg($3,SHORT_PTR_TYPE,1);
        $$ = $3; 
    }
    | LONG MUL varname{ 
        create_var_reg($3,LONG_PTR_TYPE,2);
        $$ = $3; 
    }
    ;
var_type:
    var_type_var{ $$ = $1; }
    | var_type_list{ $$ = $1; }
    | var_type_ptr{ $$ = $1; }
    ;

arg_type_ptr: 
    SHORT MUL varname{ $$ = create_arg_reg($3,SHORT_PTR_TYPE,func_pipe); }
    | LONG MUL varname{ $$ = create_arg_reg($3,LONG_PTR_TYPE,func_pipe); }
    ;
arg_type_var: 
    SHORT varname{ $$ = create_arg_reg($2,SHORT_TYPE,func_pipe); }
    | LONG varname{ $$ = create_arg_reg($2,LONG_TYPE,func_pipe); }
    | SIGN SHORT varname{ $$ = create_arg_reg($3,SHORT_TYPE,func_pipe); }
    | SIGN LONG varname{ $$ = create_arg_reg($3,LONG_TYPE,func_pipe); }
    | USIGN SHORT varname{ $$ = create_arg_reg($3,UNSIGNED_SHORT_TYPE,func_pipe); }
    | USIGN LONG varname{ $$ = create_arg_reg($3,UNSIGNED_LONG_TYPE,func_pipe); }
    ;
arg_type: 
    arg_type_var{ $$ = $1; }
    | arg_type_ptr{ $$ = $1; }
    ;



program:
    /* vide */
    | program element 

element:
    funcdeclaration { LineCount++;}
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
        int type = func[tmp].arg[r].type;
        if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
            func[tmp].num_arg=2;
            fprintf(out, " ; argument (%dL) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr);
            fprintf(out, " ; argument (%dH) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr+1);
        }else{
            func[tmp].num_arg=1;
            fprintf(out, " ; argument (%d) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr);
        }
        $$ = 1;
    } 
    | arguments_declaration COMMA arg_type
    {
        int r = $3;
        int tmp = get_func(func_pipe);
        int type = func[tmp].arg[r].type;
        if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
            func[tmp].num_arg+=2;
            fprintf(out, " ; argument (%dL) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr);
            fprintf(out, " ; argument (%dH) %s addr=0x%04x\n", func[tmp].arg[r].type,func[tmp].arg[r].name, func[tmp].arg[r].addr+1);
            $$ = $3+2;
        }else{
            func[tmp].num_arg+=1;
            fprintf(out, " ; argument (%d) %s addr=0x%04x\n", func[tmp].arg[r].type, func[tmp].arg[r].name, func[tmp].arg[r].addr);
            $$ = $3+1;
        }
    } 
    ;

arguments:
    expression {
        int tmp = get_func(func_pipe);
        int type = func[tmp].arg[$1].type;
        int r2=($1<14)?($1+1):0;
        if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$1 ,func[tmp].arg[Arg_set].addr, Arg_set);
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",r2 ,func[tmp].arg[Arg_set].addr+1, Arg_set);
            Arg_set=2;
        }else{
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$1 ,func[tmp].arg[Arg_set].addr, Arg_set);
            Arg_set=1;
        }
    }
    | arguments COMMA expression {
        int tmp = get_func(func_pipe);
        int type = func[tmp].arg[$3].type;
        int r2=($3<14)?($3+1):0;
        if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$3 ,func[tmp].arg[Arg_set].addr, Arg_set);
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",r2 ,func[tmp].arg[Arg_set].addr+1, Arg_set);
            Arg_set+=2;
        }else{
            fprintf(out, "OUTI R%d 0x%04x ; argument %d\n",$3 ,func[tmp].arg[Arg_set].addr, Arg_set);
            Arg_set+=1;
        }
    }
    ;

func_set:
    VOID funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2);
        $$ = $2;
    }
    | SHORT funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2);
        $$ = $2;
    }
    | LONG funcname{
        fprintf(out, "%s :\n", $2);
        create_func($2);
        $$ = $2;
    }
    | LONG MUL funcname{
        fprintf(out, "%s :\n", $3);
        create_func($3);
        $$ = $3;
    }
    | SHORT MUL funcname{
        fprintf(out, "%s :\n", $3);
        create_func($3);
        $$ = $3;
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
        int r = new_tmp();
        fprintf(out, "CALL ; appel de %s\n", $1);
        fprintf(out, "SUBI SP SP 1\n");
        fprintf(out, "JMP %s\n", $1);
        fprintf(out, "INI R%d 0x%x\n",r,ArgLoc-2);
        if(Arg_set != 0){
            yyerror("Function called with wrong number of arguments");
        }
        Arg_set = 0;
        free($1);
        $$ = r;
    }
    | funcname LPAREN arguments RPAREN{
        int tmp = get_func($1);
        int num_arg = func[tmp].num_arg;
        int r = new_tmp();
        int r2 = new_tmp();
        fprintf(out, "CALL ; appel de %s\n", $1);
        fprintf(out, "SUBI SP SP 1\n");
        fprintf(out, "JMP %s\n", $1);
        fprintf(out, "INI R%d 0x%x\n",r,ArgLoc-2);
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
        fprintf(out, "OUTI R%d 0x%04x\n",$2,ArgLoc-2);
        fprintf(out, "ADDI SP SP 1 ;return\nRET\n\n");
    }
    ;

const_list:
    NUMBER {
        int len = snprintf(NULL, 0, "%d", $1);
        char *str = malloc(len + 1);
        sprintf(str, "%d", $1);
        $$ = str;
    }
    | const_list COMMA NUMBER {
        int len = snprintf(NULL, 0, "%d", $3);
        char *str = malloc(1 + len + 1);
        sprintf(str, "%s,%d", $1, $3);
        free($1); 
        $$ = str;
    }
    ;

declaration:
    var_type_list ASSIGN LBRACE const_list RBRACE
    {
        int varindex = get_var_index($1,func_pipe);
        int ad = vars[varindex].addr;
        int type = vars[varindex].type;
        int r = new_tmp();
        int r2 = new_tmp();
        int num_list[strlen($4)];
        convert_str_intlist($4,num_list);
        if(type==LONG_PTR_TYPE || type==LONG_TYPE || type==UNSIGNED_LONG_PTR_TYPE || type==UNSIGNED_LONG_TYPE){
            if(intstrlen(num_list)>vars[varindex].reg)yyerror("Array size mismatch");
            for(int i=0; i<intstrlen(num_list)*2; i+=2) {
                fprintf(out, "LOAD R%d %d ; %s[%d] <- %d\n", r,num_list[i>>1]&0xffff, vars[varindex].name, i, num_list[i>>1]);
                fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i);
                fprintf(out, "LOAD R%d %d", r,(num_list[i]>>16)&0xffff);
                fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i+1);
            }
        }else{
            if(intstrlen(num_list)>vars[varindex].reg)yyerror("Array size mismatch");
            for(int i=0; i<intstrlen(num_list); i++) {
                fprintf(out, "LOAD R%d %d ; %s[%d] <- %d\n", r,num_list[i]&0xffff, vars[varindex].name, i, num_list[i]);
                fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i);
            }
        }
        free($4);
    }
    | var_type_list ASSIGN STRING
    {
        int varindex = get_var_index($1,func_pipe);
        int ad = vars[varindex].addr;
        int r = new_tmp();
        if(strlen($3)>vars[varindex].reg)yyerror("Array size mismatch");
        for(int i=0; i<strlen($3); i++) {
            fprintf(out, "LOAD R%d %d ; %s[%d] <- %d\n", r,$3[i], vars[varindex].name, i, $3[i]);
            fprintf(out, "OUTI R%d 0x%04x\n",r, ad+i);
        }
    }
    | var_type ASSIGN expression
    {
        int varindex = get_var_index($1,func_pipe);
        int ad = vars[varindex].addr;
        fprintf(out, "OUTI R%d 0x%04x ; déclaration %s addr=0x%04x\n", $3, ad, vars[varindex].name, ad);
    }
    | var_type
    {
        int varindex = get_var_index($1,func_pipe);
        int ad = vars[varindex].addr;
        fprintf(out, ";  déclaration %s addr=0x%04x\n", vars[varindex].name, ad);
    }
    ;

assignment:
    varname ASSIGN expression
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
    | MUL varname ASSIGN expression
    {
        int tmp = get_reg_addr($2);
        int r = new_tmp();
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r, tmp, $2, $4);
            fprintf(out, "OUT R%d R%d \n", $4,r );
        } else {
            int ad = get_var_addr($2,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r, ad, $2, $4);
            fprintf(out, "OUT R%d R%d \n", $4,r );
        }
        free($2);
    }
    | varname op ASSIGN expression
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $1, r);
            fprintf(out, "%s R%d R%d R%d\n",$2 , r, r, $4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, tmp, $1, r); 
        }else{
            int ad = get_var_addr($1,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
                fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
            }
            fprintf(out, "%s R%d R%d R%d\n",$2 , r, r, $4);

            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
                int res_reg = next_tmp($4);
                if(!strcmp($2,"ADD") || !strcmp($2,"SUB")){
                    fprintf(out, "%sC R%d R%d R%d\n",$2 , r2, r2, res_reg);
                }
                if(!strcmp($2,"AND") || !strcmp($2,"OR") || !strcmp($2,"XOR"))fprintf(out, "%s R%d R%d R%d\n",$2 , r2, r2, res_reg);
                if(!strcmp($2,"SHL")){
                    fprintf(out, "SHL R%d R%d R%d\n", r2, r2, res_reg);
                    fprintf(out, "SHR R%d R%d R%d\n", r3, r, res_reg);
                    fprintf(out, "OR R%d R%d R%d\n", r2, r2, r3);
                }
                if(!strcmp($2,"SHR")){
                    fprintf(out, "SHL R%d R%d R%d\n", r3, r2, res_reg);
                    fprintf(out, "OR R%d R%d R%d\n", r, r, r3);
                    fprintf(out, "SHR R%d R%d R%d\n", r2, r2, res_reg);
                }
            }
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, ad, $1, r);
            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
                fprintf(out, "OUTI R%d 0x%04x\n", r2, ad+1);
            }
        }
        free($1);
    }
    | MUL varname op ASSIGN expression
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int tmp = get_reg_addr($2);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $2, r);
            fprintf(out, "%s R%d R%d R%d\n",$3 , r, r, $5);
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r2, tmp, $2, $5);
            fprintf(out, "OUT R%d R%d \n", r, r2);

        }else{
            int ad = get_var_addr($2,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $2, r);
            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE){
                fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
            }
            fprintf(out, "%s R%d R%d R%d\n",$3 , r, r, $5);

            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE){
                int res_reg = next_tmp($5);
                if(!strcmp($3,"ADD") || !strcmp($3,"SUB")){
                    fprintf(out, "%sC R%d R%d R%d\n",$3 , r2, r2, res_reg);
                }
                if(!strcmp($3,"AND") || !strcmp($3,"OR") || !strcmp($3,"XOR"))fprintf(out, "%s R%d R%d R%d\n",$3 , r2, r2, res_reg);
                if(!strcmp($3,"SHL")){
                    fprintf(out, "SHL R%d R%d R%d\n", r2, r2, res_reg);
                    fprintf(out, "SHR R%d R%d R%d\n", r3, r, res_reg);
                    fprintf(out, "OR R%d R%d R%d\n", r2, r2, r3);
                }
                if(!strcmp($3,"SHR")){
                    fprintf(out, "SHL R%d R%d R%d\n", r3, r2, res_reg);
                    fprintf(out, "OR R%d R%d R%d\n", r, r, r3);
                    fprintf(out, "SHR R%d R%d R%d\n" , r2, r2, res_reg);
                }
            }
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r3, ad, $2, r);
            fprintf(out, "OUT R%d R%d \n", r, r3);
            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE){
                fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r3, ad+1, $2, r2);
                fprintf(out, "OUT R%d R%d \n", r2, r3);
            }
        }
        free($2);
    }
    | varname op ASSIGN NUMBER
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $1, r);
            fprintf(out, "%sI R%d R%d %d\n",$2 , r, r, (unsigned short)$4);
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, tmp, $1, r); 
        } else {
            int ad = get_var_addr($1,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $1, r);
            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
            fprintf(out, "%sI R%d R%d %d\n",$2 , r, r, (unsigned short)$4);
            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
                
                if(!strcmp($2,"ADD") || !strcmp($2,"SUB")){
                    fprintf(out, "LOAD R%d %d\n",r3, (unsigned short)($4>>16));
                    fprintf(out, "%sC R%d R%d R%d\n",$2 , r2, r2, r3);
                }
                if(!strcmp($2,"AND") || !strcmp($2,"OR") || !strcmp($2,"XOR"))fprintf(out, "%sI R%d R%d %d\n",$2 , r2, r2, (unsigned short)($4>>16));
                if(!strcmp($2,"SHL")){
                    fprintf(out, "SHLI R%d R%d %d\n",$2 , r2, r2, (unsigned short)($4));
                    fprintf(out, "SHRI R%d R%d %d\n",$2 , r3, r, (unsigned short)(16-$4));
                    fprintf(out, "OR R%d R%d R%d\n",$2 , r2, r2, r3);
                }
                if(!strcmp($2,"SHR")){
                    fprintf(out, "SHLI R%d R%d %d\n",$2 , r3, r2, (unsigned short)(16-$4));
                    fprintf(out, "OR R%d R%d R%d\n",$2 , r, r, r3);
                    fprintf(out, "SHRI R%d R%d %d\n",$2 , r2, r2, (unsigned short)($4));
                }
            }
            fprintf(out, "OUTI R%d 0x%04x ; %s <- R%d\n", r, ad, $1, r);
            if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "OUTI R%d 0x%04x\n", r2, ad+1);
        }
        free($1);
    }
    | MUL varname op ASSIGN NUMBER
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int tmp = get_reg_addr($2);
        if (tmp != -1) {
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, tmp, $2, r);
            fprintf(out, "%sI R%d R%d %d\n",$3 , r, r, (unsigned short)$5);
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r2, tmp, $2, r);
            fprintf(out, "OUT R%d R%d \n", r, r2);
        } else {
            int ad = get_var_addr($2,func_pipe);
            fprintf(out, "INI R%d 0x%04x ; %s -> R%d\n", r, ad, $2, r);
            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
            fprintf(out, "%sI R%d R%d %d\n",$3 , r, r, (unsigned short)$5);
            
            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE){
                
                if(!strcmp($3,"ADD") || !strcmp($3,"SUB")){
                    fprintf(out, "LOAD R%d %d\n",r3, (unsigned short)($5>>16));
                    fprintf(out, "%sC R%d R%d R%d\n",$3 , r2, r2, r3);
                }
                if(!strcmp($3,"AND") || !strcmp($3,"OR") || !strcmp($3,"XOR"))fprintf(out, "%sI R%d R%d %d\n",$3 , r2, r2, (unsigned short)($5>>16));
                if(!strcmp($3,"SHL")){
                    fprintf(out, "SHLI R%d R%d %d\n",$3 , r2, r2, (unsigned short)($5));
                    fprintf(out, "SHRI R%d R%d %d\n",$3 , r3, r, (unsigned short)(16-$5));
                    fprintf(out, "OR R%d R%d R%d\n",$3 , r2, r2, r3);
                }
                if(!strcmp($2,"SHR")){
                    fprintf(out, "SHLI R%d R%d %d\n",$3 , r3, r2, (unsigned short)(16-$5));
                    fprintf(out, "OR R%d R%d R%d\n",$3 , r, r, r3);
                    fprintf(out, "SHRI R%d R%d %d\n",$3 , r2, r2, (unsigned short)($5));
                }
            }
            fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r3, ad, $2, r);
            fprintf(out, "OUT R%d R%d \n", r, r3);
            if(get_var_type($2,func_pipe)==LONG_PTR_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($2,func_pipe)==LONG_TYPE || get_var_type($2,func_pipe)==UNSIGNED_LONG_TYPE){
                fprintf(out, "INI R%d 0x%04x ; *%s <- R%d\n", r3, ad+1, $2, r);
                fprintf(out, "OUT R%d R%d \n", r2, r3);
            }
        }
        free($2);
    }
    | varname PLUS PLUS
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
        fprintf(out, "ADDI R%d R%d 1\n", r, r);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
            fprintf(out, "LOAD R%d 0\n", r3);
            fprintf(out, "ADDC R%d R%d R%d\n", r2, r2, r3);
        }
        fprintf(out, "OUTI R%d 0x%04x ; %s <- %s+1\n", r, ad, $1, $1);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "OUTI R%d 0x%04x\n", r2, ad+1);
        free($1);
    }
    | varname MINUS MINUS
    {
        int r = new_tmp();
        int r2 = new_tmp();
        int r3 = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "INI R%d 0x%04x\n", r2, ad+1);
        fprintf(out, "SUBI R%d R%d 1\n", r, r);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE){
            fprintf(out, "LOAD R%d 0\n", r3);
            fprintf(out, "SUBC R%d R%d R%d\n", r2, r2, r3);
        }
        fprintf(out, "OUTI R%d 0x%04x ; %s <- %s+1\n", r, ad, $1, $1);
        if(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_PTR_TYPE || get_var_type($1,func_pipe)==LONG_TYPE || get_var_type($1,func_pipe)==UNSIGNED_LONG_TYPE)fprintf(out, "OUTI R%d 0x%04x\n", r2, ad+1);
        free($1);
    }
    | varname LBRACKET NUMBER RBRACKET ASSIGN expression
    {
        char* var_name = malloc(strlen($1)+50);
        int tmp = get_reg_addr($1);
        if (tmp != -1) {
            sprintf(var_name," Register %s already exists with this name",$1);
            yyerror(var_name);
        }else {
            int ad = get_var_addr($1,func_pipe);
            if(ad>=ArgLoc && ad<=ArgLocMax){
                int r = new_tmp();
                fprintf(out, "INI R%d 0x%04x ; %s[%d] <- R%d\n", r, ad, $1, $3, $6);
                fprintf(out, "ADDI R%d R%d %d\n", r, r, $3);
                fprintf(out, "OUT R%d R%d\n", $6, r);
            }else{
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
            int ad = get_var_addr($1,func_pipe);
            int r = new_tmp();
            if(!(get_var_type($1,func_pipe)==LONG_PTR_TYPE || get_var_type($1,func_pipe)==SHORT_PTR_TYPE))yyerror("variable not of type ptr/array");
            if(ad>=ArgLoc && ad<=ArgLocMax){
                fprintf(out, "INI R%d 0x%04x ; %s[%d] <- R%d\n", r, ad, $1, $3, $6);
                fprintf(out, "ADD R%d R%d R%d\n", r, r, $3);
                fprintf(out, "OUT R%d R%d\n", $6, r);
            }else{
                fprintf(out, "ADDI R%d R%d 0x%04x\n",r, $3, ad);
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
        int r2 = -48;
        fprintf(out, "%s R%d R%d R%d\n",$2 , r, $1, $3);
        $$ = r;
    }
    | BNOT LPAREN expression BAND NUMBER RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NANDI R%d R%d %d\n", r, $3, $5&0xffff);
        $$ = r;
    }
    | BNOT LPAREN NUMBER BAND expression RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NANDI R%d R%d %d\n", r, $5, $3&0xffff);
        $$ = r;
    }
    | BNOT LPAREN expression BAND expression RPAREN
    {
        int r = new_tmp();
        fprintf(out, "NAND R%d R%d R%d\n", r, $5, $3);
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
        int type = get_var_type($1,func_pipe);
        if(!(type==LONG_PTR_TYPE || type==SHORT_PTR_TYPE))yyerror("variable not of type ptr/array");    //Attention erreur
        if(type==LONG_PTR_TYPE){
            if(ad>=ArgLoc && ad<=ArgLocMax){
                fprintf(out, "INI R%d 0x%04x\n", r, ad);
                fprintf(out, "ADDI R%d R%d %d\n", r, r, $3*2);
                fprintf(out, "IN R%d R%d ; lecture %s[%d] -> R%d\n", r, r, $1, $3, r);
            }else{
                fprintf(out, "INI R%d 0x%04x ; lecture %s[%d] -> R%d\n", r, ad+($3*2), $1, $3, r);
                fprintf(out, "INI R%d 0x%04x", r, ad+($3*2)+1);
            }
        }else{
            if(ad>=ArgLoc && ad<=ArgLocMax){
                fprintf(out, "INI R%d 0x%04x\n", r, ad);
                fprintf(out, "ADDI R%d R%d %d\n", r, r, $3);
                fprintf(out, "IN R%d R%d ; lecture %s[%d] -> R%d\n", r, r, $1, $3, r);
            }else{
                fprintf(out, "INI R%d 0x%04x ; lecture %s[%d] -> R%d\n", r, ad+$3, $1, $3, r);
            }
        }
        $$ = r;
        free($1);
    }
    | varname LBRACKET expression RBRACKET
    {
        int r = new_tmp();
        int ad = get_var_addr($1,func_pipe);
        int type = get_var_type($1,func_pipe);
        if(!(type==LONG_PTR_TYPE || type==SHORT_PTR_TYPE))yyerror("variable not of type ptr/array");
        if(type==LONG_PTR_TYPE){
            if(ad>=ArgLoc && ad<=ArgLocMax){
                fprintf(out, "INI R%d 0x%04x\n", r, ad);
                fprintf(out, "ADD R%d R%d R%d\n", r, r, $3);
                fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r, r, $1, $3, r);
            }else{
                fprintf(out, "ADDI R%d R%d 0x%04x\n", r, $3, ad);
                fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r, r, $1, $3, r);
            }
        }else{
           if(ad>=ArgLoc && ad<=ArgLocMax){
                fprintf(out, "INI R%d 0x%04x\n", r, ad);
                fprintf(out, "ADD R%d R%d R%d\n", r, r, $3);
                fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r, r, $1, $3, r);
            }else{
                fprintf(out, "ADDI R%d R%d 0x%04x\n", r, $3, ad);
                fprintf(out, "IN R%d R%d ; lecture %s[R%d] -> R%d\n", r, r, $1, $3, r);
            }
        }
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
            if(vartype == UNSIGNED_LONG_PTR_TYPE || vartype == LONG_PTR_TYPE){
                fprintf(out, "LOAD R%d 0x%04x ; lecture &%s -> %d\n", r, ad, $1, r);
            }else if(vartype == UNSIGNED_LONG_TYPE || vartype == LONG_TYPE){
                fprintf(out, "INI R%d 0x%04x ; lecture %s -> R%d\n", r, ad, $1, r);
            }else if(vartype == UNSIGNED_SHORT_PTR_TYPE || vartype == SHORT_PTR_TYPE){
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
    | MUL varname
    {
        int r = new_tmp();
        int r1 = new_tmp();
        int ad = get_var_addr($2,func_pipe);
        fprintf(out, "INI R%d 0x%04x ; lecture *%s -> %d\n", r, ad, $2, r);
        fprintf(out, "IN R%d R%d \n",r1, r);
        $$ = r1;
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
        fprintf(out, "LOAD R%d %d\n", r, $1&0xffff);
        $$ = r;
    }
    ;

condition:
    JMCARRY
    {
        TMP_pipe =  read_label();
        fprintf(out,"JMC if_%04d\n", TMP_pipe);      // Si égal (0), aller à if
        fprintf(out,"JMP else_if_%04d\n", TMP_pipe);   // Sinon, aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);
        $$ = TMP_pipe;
    }
    | expression EQ expression
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
        fprintf(out,"JMC else_if_%04d\n", TMP_pipe);       // Si négatif, aller à if
        fprintf(out,"if_%04d :\n", TMP_pipe);   // Si positif, aller à end_if
        $$ = TMP_pipe;
    }
    | expression GE expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition >=\n", r, $1, $3);  // CORRIGÉ: $1 - $3
        fprintf(out,"JMC else_if_%04d\n", TMP_pipe);   // Si négatif, aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);       // Si positif, aller à if
        $$ = TMP_pipe;
    }
    | expression LT expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition <\n", r, $1, $3);
        fprintf(out,"JMC if_%04d\n", TMP_pipe);       // Si négatif, aller à if
        fprintf(out,"JMP else_if_%04d\n", TMP_pipe);   // Sinon (>=0), aller à end_if
        fprintf(out,"if_%04d :\n", TMP_pipe);
        $$ = TMP_pipe;
    }
    | expression GT expression
    {
        int r = new_tmp();
        TMP_pipe = read_label();
        fprintf(out,"SUB R%d R%d R%d ; condition >\n", r, $3, $1);   // CORRIGÉ: $1 - $3
        fprintf(out,"JMC if_%04d\n", TMP_pipe);   // Si négatif, aller à end_if
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
        fprintf(out,"JMP for_%04d\n", tmp);
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
    fclose(out);
    fclose(yyin);
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