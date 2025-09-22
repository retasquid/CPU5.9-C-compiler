#ifndef ARDUINO_H
#define ARDUINO_H

#define CLOCK_HZ 100000
#define CLOCK_KHZ 100
#define CLOCK_MHZ 0

#define HIGH 1
#define LOW 0

void Serialbegin(int baudH, int baudL){
    BAUDH=baudH;
    BAUDL=baudL;
    return 0;
}

void SerialPrint(char* message){
    int delay_i;
    for(int SerialPrint_i = -1; message[SerialPrint_i+1];SerialPrint_i++){
        UART = message[SerialPrint_i]|0x100;
        delay_i = 0;
        while(STATUS&0x02){delay_i+=4;}
        UART = 0;
        while(delay_i){delay_i--;}
    }
    return 0;
}

void SerialPrintln(char* messageln){
    int delayln_i;
    for(int SerialPrintln_i = -1; messageln[SerialPrintln_i+1];SerialPrintln_i++){
        delayln_i = 0;
        UART = messageln[SerialPrintln_i]|0x100;
        while(STATUS&0x02){delayln_i+=4;}
        UART = 0;
        while(delayln_i){delayln_i--;}
    }
    UART = 0x10a;
    delayln_i = 0;
    while(STATUS&0x02){delayln_i+=4;}
    UART = 0;
    while(delayln_i){delayln_i--;}
    UART = 0x10d;
    delayln_i = 0;
    while(STATUS&0x02){delayln_i+=4;}
    UART = 0;
    while(delayln_i){delayln_i--;}
    return 0;
}

void SerialWrite(char charactere){
    short delay_j = 0;
    UART = charactere|0x100;
    while(STATUS&0x02){delay_j+=4;}
    UART = 0;
    while(delay_j){delay_j--;}
    return 0;
}

void SerialRead(char* input_message, int len_input_message){
    int lock = 1;
    char tmp = 0;
    int cnt_in=0;
    while(tmp!='\r'){
        while(lock){
            tmp = UART;
            if(tmp){
                lock=0;
            }
        }
        lock=1;
        UART = tmp|0x100;
        while(STATUS&0x02){}
        UART = 0;
        if(tmp==8){
            if(cnt_in){
                cnt_in--;
            }
            input_message[cnt_in]=0;
        }else if(cnt_in<len_input_message){
            input_message[cnt_in]=tmp;
            cnt_in++;
        }
    }
    input_message[cnt_in-1]='\0';
    return 0;
}

void digitalWrite(char pin_write, char state){
    if(pin_write<=15){
        pin_write = 1 << pin_write;
        if(state){
            GPO0 |= pin_write;
        }else{
            GPO0 &= ~pin_write;
        }
    }else{
        pin_write = 1 << (pin_write-16);
        if(state){
            GPO1 |=pin_write;
        }else{
            GPO1 &= ~pin_write;
        }
    }
    return 0;
}

int digitalRead(char pin_read){
    int pin_data;
    if(pin_read<=15){
        pin_data = (GPI0 & (1<<pin_read))>>(pin_read);
    }else{
        pin_data = (GPI1 & (1<<pin_read-15))>>pin_read-15;
    }
    return pin_data;
}

void delay(int microsec){
    while(microsec){
        for(int khz_count = 0; khz_count<CLOCK_KHZ; khz_count+=9){}
        microsec--;
    }
    return 0;
}

short div(short dividend, short divisor) {
    if (divisor == 0) return 0xFFFF; // Division par zéro protection

    short quotient = 0;
    short remainder = dividend;

    // Trouver le nombre de bits à aligner
    short shift = 0;
    char cond = 1;
    while (cond) {
        if((divisor << shift) <= remainder){
            if(shift < 16){
                shift++;
            }else{cond=0;}
        }else{cond=0;}
    }

    // Revenir d'un cran en arrière si on a dépassé
    if (shift) shift--;

    while(shift<65535){
        short sub = divisor << shift;
        if (remainder >= sub) {
            remainder -= sub;
            quotient |= 1 << shift;
        }
        shift--;
    }

    return quotient;
}

#endif