# CPU5.9-C-compiler
Custom basic C compiler based on flex and bison.

## Installation
1. Compile the lexer.l file and parser.y file: 
```
flex lexer.l
bison -d parser.y
```
2. Compile the C compiler:
```
gcc parser.tab.c lex.yy.c -o CcompCPU5
```
3. You can now compile C code with CcompCPU5
## Use
1. Preprocessing for "#" lines
```
gcc -E -P main.c -o main.i
```
2. Compiling the ".i"
```
./CcompCPU5 main.i -o main.asm
```
## Limitations
The C implemented is very basic with only "short" realy working(int and char are shorts).
Pointers are not available but I'm working on that, list however is available.

The compile process don't have a linker so the file include should have the code in them.

The conditions can't be stacked like "if((i>0)&&(i<10)){}" because of CPU5.9 internal limitation but instead you can combine IFs.

For now "*" and "/" output MULT and DIV operations that CPU5.9 can't read so consider replacing them with functions like ""mult(int a, int b)" or "div(int a, int b)"


