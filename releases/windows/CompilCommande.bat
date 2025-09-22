@Win_bison -d parser.y
@Win_flex lexer.l
@gcc parser.tab.c lex.yy.c -o CcompCPU5
@gcc -E -P ../{YOUR_PATH}/main.c -o ../{YOUR_PATH}/main.i
@CcompCPU5.exe ../{YOUR_PATH}/main.i -o ../{YOUR_PATH}/main.asm
@python compiler.py ../{YOUR_PATH}/main.asm ../../{YOUR_PATH}/prog.h