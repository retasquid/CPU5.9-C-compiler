@Win_bison -d parser.y
@Win_flex lexer.l
@gcc parser.tab.c lex.yy.c -o CcompCPU5
@gcc -E -P ../ProjetC/main.c -o ../ProjetC/main.i
@CcompCPU5.exe ../ProjetC/main.i -o ../ProjetC/main.asm
@python compiler.py ../ProjetC/main.asm ../ProjetC/main.h
