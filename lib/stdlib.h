#ifndef STDLIB_H
#define STDLIB_H
int atoi(char* str_atoi){
    int atoi_ptr = 0;
    int atoi_int=0;
    int atoi_tmp;
    while(atoi_ptr<=4){
        atoi_tmp = str_atoi[atoi_ptr];
        if(atoi_tmp<=47)return atoi_int;
        if(atoi_tmp>=58)return atoi_int;
        atoi_int = (atoi_int<<3) + (atoi_int<<1) + atoi_tmp-'0';
        atoi_ptr++;
    }
    return atoi_int;
}

int itoa( int itoa_value, char * itoa_str){
    int itoa_powers[5] = {10000, 1000, 100, 10, 1};
    int itoa_started = 0;
    int itoa_pos = 0;
    int itoa_i = 0;
    while(itoa_i <= 4){
        int itoa_count = 0;
        while (itoa_value >= itoa_powers[itoa_i]) {
            itoa_value -= itoa_powers[itoa_i];
            itoa_count++;
        }
        int itoa_cond = 0;
        if (itoa_count)itoa_cond=1;
        if (itoa_started)itoa_cond=1;
        if (itoa_i == 4)itoa_cond=1;
        if(itoa_cond){
            itoa_str[itoa_pos] = '0' + itoa_count;
            itoa_pos++;
            itoa_started = 1;
        }
        itoa_i++;
    }

    itoa_str[itoa_pos] = '\0';
    return 0;
}

int itoa16( int itoa16_value, char * itoa16_str){
    int itoa16_i = 16;
    int itoa16_pos = 0;
    int itoa16_tmp;
    while(itoa16_i){
        itoa16_i-=4;
        itoa16_tmp = (itoa16_value>>itoa16_i)&0xf;
        if(itoa16_tmp<=9){
            itoa16_str[itoa16_pos] = itoa16_tmp+48;
        }else{
            itoa16_str[itoa16_pos] = itoa16_tmp+87;
        }
        itoa16_pos++;
    }
    itoa16_str[itoa16_pos] = '\0'; // Fin de chaîne
    return 0;
}

#endif