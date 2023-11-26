#include "tokens.h"

// clang-format off
static const uint8_t keywords2[] = {
    'c','p',TOK_CP,
    'd','i',TOK_DI,
    'e','i',TOK_EI,
    'e','x',TOK_EX,
    'i','m',TOK_IM,
    'i','n',TOK_IN,
    'j','p',TOK_JP,
    'j','r',TOK_JR,
    'l','d',TOK_LD,
    'o','r',TOK_OR,
    'r','l',TOK_RL,
    'r','r',TOK_RR,
};
static const uint8_t keywords3[] = {
    'a','d','c',TOK_ADC,
    'a','d','d',TOK_ADD,
    'a','n','d',TOK_AND,
    'b','i','t',TOK_BIT,
    'c','c','f',TOK_CCF,
    'c','p','d',TOK_CPD,
    'c','p','i',TOK_CPI,
    'c','p','l',TOK_CPL,
    'd','a','a',TOK_DAA,
    'd','e','c',TOK_DEC,
    'e','n','d',TOK_END,
    'e','q','u',TOK_EQU,
    'e','x','x',TOK_EXX,
    'i','n','c',TOK_INC,
    'i','n','d',TOK_IND,
    'i','n','i',TOK_INI,
    'l','d','d',TOK_LDD,
    'l','d','i',TOK_LDI,
    'n','e','g',TOK_NEG,
    'n','o','p',TOK_NOP,
    'o','r','g',TOK_ORG,
    'o','u','t',TOK_OUT,
    'p','o','p',TOK_POP,
    'r','e','s',TOK_RES,
    'r','e','t',TOK_RET,
    'r','l','a',TOK_RLA,
    'r','l','c',TOK_RLC,
    'r','l','d',TOK_RLD,
    'r','r','a',TOK_RRA,
    'r','r','c',TOK_RRC,
    'r','r','d',TOK_RRD,
    'r','s','t',TOK_RST,
    's','b','c',TOK_SBC,
    's','c','f',TOK_SCF,
    's','e','t',TOK_SET,
    's','l','a',TOK_SLA,
    's','l','l',TOK_SLL,
    's','r','a',TOK_SRA,
    's','r','l',TOK_SRL,
    's','u','b',TOK_SUB,
    'x','o','r',TOK_XOR,
};
static const uint8_t keywords4[] = {
    'c','a','l','l',TOK_CALL,
    'c','p','d','r',TOK_CPDR,
    'c','p','i','r',TOK_CPIR,
    'd','e','f','b',TOK_DEFB,
    'd','e','f','s',TOK_DEFS,
    'd','e','f','w',TOK_DEFW,
    'd','j','n','z',TOK_DJNZ,
    'h','a','l','t',TOK_HALT,
    'i','n','d','r',TOK_INDR,
    'i','n','i','r',TOK_INIR,
    'l','d','d','r',TOK_LDDR,
    'l','d','i','r',TOK_LDIR,
    'o','t','d','r',TOK_OTDR,
    'o','t','i','r',TOK_OTIR,
    'o','u','t','d',TOK_OUTD,
    'o','u','t','i',TOK_OUTI,
    'p','u','s','h',TOK_PUSH,
    'r','e','t','i',TOK_RETI,
    'r','e','t','n',TOK_RETN,
    'r','l','c','a',TOK_RLCA,
    'r','r','c','a',TOK_RRCA,
};
static const uint8_t keywords5[] = {
    'p','h','a','s','e',TOK_PHASE,
};
static const uint8_t keywords6[] = {
    'i','n','c','b','i','n',TOK_INCBIN,
};
static const uint8_t keywords7[] = {
    'd','e','p','h','a','s','e',TOK_DEPHASE,
    'i','n','c','l','u','d','e',TOK_INCLUDE,
};
// clang-format on

const uint8_t *keywords[] = {
    keywords2,
    keywords3,
    keywords4,
    keywords5,
    keywords6,
    keywords7,
};
const uint8_t num_keywords[] = {
    sizeof(keywords2) / 3,
    sizeof(keywords3) / 4,
    sizeof(keywords4) / 5,
    sizeof(keywords5) / 6,
    sizeof(keywords6) / 7,
    sizeof(keywords7) / 8,
};
