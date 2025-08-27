# CPU5.9-C-compiler
Custom basic C compiler based on flex and bison.

## Installation
1. Compile the `lexer.l` file and `parser.y` file:
windows : 
```
win_flex lexer.l
win_bison -d parser.y
```
linux : 
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
3. Compile in machine code

See my ASM compiler here : https://github.com/retasquid/CPU5-ASM-Compiler

## Limitations
The C implemented is very basic with only `short` realy working(`int` and `char` are understood`shorts`).
Pointers and list are available.

The compile process don't have a linker so the file include should have the code in them.

The conditions operation `&&`, `||` and `!` are not implemented and conditions can't be stacked like `if((i>0)&&(i<10)){}` for now, but instead you can combine IFs. 

However, you can combine expressions like `if((i&1)==mult(4,6)){}`

For now `*` and `/` operations output MULT and DIV code and an error message because the CPU5.9 can't mult or divide. Consider replacing them with functions like `mult(int a, int b)` or `div(int a, int b)`


