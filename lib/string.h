#ifndef STRING_H
#define STRING_H
char* strcpy(char* strcpy_strout,char* strcpy_strin){
    int strcpy = 0;
    while(strcpy_strin[strcpy]){
        strcpy_strout[strcpy] = strcpy_strin[strcpy];
        strcpy++;
    }
    strcpy_strout[strcpy] = '\0';
    return strcpy_strin;
}

int strlen(char* strlen_strout){
    int strlen_i = 0;
    while(strlen_strout[strlen_i])strlen_i++;
    return strlen_i;
}

int strcmp(char* strcmp_str1,char* strcmp_str2){
    int strcmp = 0;
    int strcmp_tmp;
    while(strcmp_str1[strcmp]){
        strcmp_tmp = strcmp_str1[strcmp] - strcmp_str2[strcmp];
        if(strcmp_tmp)return strcmp_tmp;
        strcmp++;
    }
    return 0;
}

#endif