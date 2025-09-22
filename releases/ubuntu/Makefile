all:
	@bison -d parser.y
	@flex lexer.l
	@gcc parser.tab.c lex.yy.c -o CcompCPU5
	@gcc -E -P ../{YOUR_PATH}/main.c -o ../{YOUR_PATH}/main.i
	@./CcompCPU5 ../{YOUR_PATH}/main.i -o ../{YOUR_PATH}/main.asm
	@python3 compiler.py ../{YOUR_PATH}/main.asm ../../{YOUR_PATH}/prog.h
