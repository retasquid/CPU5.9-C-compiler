#ifndef STR_PROCESS_H
#define STR_PROCESS_H
char* process_escapes(const char* input, int len) {
    char* result = malloc(len + 1);
    int i = 0, j = 0;
    
    while (i < len) {
        if (input[i] == '\\' && i + 1 < len) {
            switch (input[i + 1]) {
                case 'n':  result[j++] = '\n'; break;
                case '0':  result[j++] = '\0' ; break;
                case 't':  result[j++] = '\t'; break;
                case 'r':  result[j++] = '\r'; break;
                case '\\': result[j++] = '\\'; break;
                case '"':  result[j++] = '"'; break;
                default:
                    result[j++] = input[i];
                    result[j++] = input[i + 1];
                    break;
            }
            i += 2;
        } else {
            result[j++] = input[i++];
        }
    }
    result[j] = '\0';
    return result;
}

int get_escape_char(char c) {
    switch(c) {
        case 'n': return '\n';
        case 't': return '\t';
        case 'r': return '\r';
        case '0': return '\0';
        case '\\': return '\\';
        case '\'': return '\'';
        default: return c;
    }
}
#endif