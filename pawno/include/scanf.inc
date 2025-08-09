/* scanf.inc - Simples definição para sscanf e format types usados em SA-MP */
#if defined _scanf_included
    #endinput
#endif
#define _scanf_included

native sscanf(const string[], const format[], {Float,_}:...);
#define SSCANF_FAIL 0
