/* GENIUS Calculator
 * Copyright (C) 1997-2002 George Lebl
 *
 * Author: George Lebl
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the  Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 * USA.
 */
%{
#include "config.h"

#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "mpwrap.h"
#include "eval.h"
#include "dict.h"
#include "calc.h"
#include "parse.h"
#include "util.h"

int lex_fd[2];
int first_tok = STARTTOK;
int return_ret = FALSE;
int parenth_depth = 0;
int lex_init = TRUE;
extern GSList *evalstack;
extern int got_eof;
static int matrix_entry = 0;
static GSList *matrix_entry_stack = NULL;


#define NO_RET {return_ret = FALSE;}
#define DO_RET { \
	if(!parenth_depth) \
		return_ret = TRUE; \
	else \
		return_ret = FALSE; \
}

static GHashTable *fp_hash = NULL;

void my_yy_open(FILE *fp);
void my_yy_parse(FILE *fp);
void my_yy_close(FILE *fp);

void
my_yy_open(FILE *fp)
{
	YY_BUFFER_STATE buf;
	if(!fp_hash)
		fp_hash = g_hash_table_new(NULL, NULL);

	buf = g_hash_table_lookup(fp_hash, fp);
	if(buf)
		return;

	buf = yy_create_buffer(fp, YY_BUF_SIZE);
	g_hash_table_insert(fp_hash, fp, buf);
}

void
my_yy_parse(FILE *fp)
{
	YY_BUFFER_STATE buf;

	g_assert(fp_hash);

	buf = g_hash_table_lookup(fp_hash, fp);

	yy_switch_to_buffer(buf);
	yyparse();
}

void
my_yy_close(FILE *fp)
{
	YY_BUFFER_STATE buf;

	/* don't close the stdin */
	if(fp == stdin)
		return;

	g_assert(fp_hash);

	buf = g_hash_table_lookup(fp_hash, fp);

	yy_delete_buffer(buf);

	 g_hash_table_remove(fp_hash, fp);
}

%}

%%

%{
	if(lex_init) {
		return_ret = FALSE;
		parenth_depth = 0;
		matrix_entry = 0;
		matrix_entry_stack = NULL;
		lex_init = FALSE;
	}
	
	if(first_tok!=INT_MAX) {
		int i = first_tok;
		first_tok = INT_MAX;
		return i;
	}
%}


#.*$		; /*comment, ignore*/

^[ 	]*load[ 	]+<([^>]|\\>)*>[ 	]*$ {
			char *s;
			char *end;
			if(evalstack || parenth_depth) {REJECT;}
			s=strchr(yytext,'<')+1; /*find the beginning*/
			end=strrchr(yytext,'>'); /*find the end*/
			s = unescape_string(s,end,NULL);
			yylval.id = g_strconcat(LIBRARY_DIR,"/",s,NULL);
			g_free(s);
			DO_RET;
			return LOADFILE;
		}

^[ 	]*load[ 	]+[^ 	].*$ {
			char *s;
			if(evalstack || parenth_depth) {REJECT;}
			s=strchr(yytext,'d')+1; /*move after the load*/
			/*btw from the above RE we know this will work*/
			while(*s==' ' || *s=='\t')
				s++;
			yylval.id = g_strdup(s);
			DO_RET;
			return LOADFILE_GLOB;
		}

^[ 	]*plugin[ 	]+[^ 	].*$ {
			char *s;
			if(evalstack || parenth_depth) {REJECT;}
			s=strchr(yytext,'n')+1; /*move after the load*/
			/*btw from the above RE we know this will work*/
			while(*s==' ' || *s=='\t')
				s++;
			yylval.id = g_strdup(s);
			DO_RET;
			return LOAD_PLUGIN;
		}

";"		{
			if (matrix_entry &&
			    GPOINTER_TO_INT(matrix_entry_stack->data) == 0) {
				return NEXTROW;
			}
			DO_RET;
			return SEPAR;
		}

\"([^"]|\\\")*\"	{ 
			DO_RET;
			yylval.id = unescape_string(&yytext[1],NULL,NULL);
			/*kill the trailing "*/
			yylval.id[strlen(yylval.id)-1]='\0';
			return STRING;
		}

==		{ NO_RET; return EQ_CMP; }
!=		{ NO_RET; return NE_CMP; }
"<>"		{ NO_RET; return NE_CMP; }
"<=>"		{ NO_RET; return CMP_CMP; }

"<="		{ NO_RET; return LE_CMP; }
">="		{ NO_RET; return GE_CMP; }

"<"		{ NO_RET; return LT_CMP; }
">"		{ NO_RET; return GT_CMP; }

=		{ NO_RET; return EQUALS; }

not		{ NO_RET; return LOGICAL_NOT; }
and		{ NO_RET; return LOGICAL_AND; }
xor		{ NO_RET; return LOGICAL_XOR; }
or		{ NO_RET; return LOGICAL_OR; }

while		{ NO_RET; return WHILE; }
until		{ NO_RET; return UNTIL; }
for		{ NO_RET; return FOR; }
sum		{ NO_RET; return SUM; }
prod		{ NO_RET; return PROD; }
do		{ NO_RET; return DO; }
to		{ NO_RET; return TO; }
by		{ NO_RET; return BY; }
in		{ NO_RET; return IN; }
if		{ NO_RET; return IF; }
then		{ NO_RET; return THEN; }
else		{ NO_RET; return ELSE; }

function	{ NO_RET; return FUNCTION; }
call		{ NO_RET; return CALL; }

return		{ NO_RET; return RETURNTOK; }
bailout		{ DO_RET; return BAILOUT; }
exception	{ DO_RET; return EXCEPTION; }
continue	{ DO_RET; return CONTINUE; }
break		{ DO_RET; return BREAK; }

mod		{ NO_RET; return MOD; }

null		{ DO_RET; return '.'; }

"@("		{
			parenth_depth++;
			if (matrix_entry_stack != NULL)
				matrix_entry_stack->data =
					GINT_TO_POINTER
					  (GPOINTER_TO_INT(matrix_entry_stack->data) + 1);
			NO_RET;
			return AT;
		}
\.\.		{
			NO_RET;
			return REGION_SEP;
		}
		
[[][\t ]*	{
			matrix_entry++;
			parenth_depth++;
			matrix_entry_stack =
				g_slist_prepend (matrix_entry_stack,
						 GINT_TO_POINTER (0));
			NO_RET;
			return '[';
		}

[\t ]*[]]	{
			GSList *li;
			matrix_entry--;
			parenth_depth--;
			li = matrix_entry_stack;
			matrix_entry_stack = g_slist_remove_link (matrix_entry_stack, li);
			g_slist_free_1 (li);
			DO_RET;
			return ']';
		}
			

[({]		{
			parenth_depth++;
			if (matrix_entry_stack != NULL)
				matrix_entry_stack->data =
					GINT_TO_POINTER
					  (GPOINTER_TO_INT(matrix_entry_stack->data) + 1);
			NO_RET;
			return yytext[0];
		}

[)}]		{
			parenth_depth--;
			if (matrix_entry_stack != NULL)
				matrix_entry_stack->data =
					GINT_TO_POINTER
					  (GPOINTER_TO_INT(matrix_entry_stack->data) - 1);
			DO_RET;
			return yytext[0];
		}

[a-zA-Z_][a-zA-Z0-9_]*	{
				/* identifier*/
				yylval.id = g_strdup(yytext);
				DO_RET;
				return FUNCID;
			}
			
[1-9][0-9]*[ ][1-9][0-9]*[/][1-9][0-9]*	{
			mpw_init(yylval.val);
			mpw_set_str(yylval.val,yytext,10);
			DO_RET;
			return NUMBER;
		}

[0-9]*\.[0-9]+[eE@][-+]?[0-9]+i	|
[0-9]+[eE@][-+]?[0-9]+i		|
[0-9]+i				|
[0-9]*\.[0-9]+i	{
			char *s;
			if(yytext[0] == '.')
				s = g_strconcat("0",&yytext[0],NULL);
			else
				s = g_strdup(yytext);
			mpw_init(yylval.val);
			mpw_set_str_complex(yylval.val,s,10);
			g_free(s);
			DO_RET;
			return NUMBER;
		}


[0-9]*\.[0-9]+[eE@][-+]?[0-9]+	|
[0-9]+[eE@][-+]?[0-9]+		|
[0-9]*\.[0-9]+	{
			char *s;
			if(yytext[0] == '.')
				s = g_strconcat("0",&yytext[0],NULL);
			else
				s = g_strdup(yytext);
			mpw_init(yylval.val);
			mpw_set_str_float(yylval.val,s,10);
			g_free(s);
			DO_RET;
			return NUMBER;
		}


([1-3][0-9]|[1-9])\\[0-9a-zA-Z]+	{
			char *s;
			int base;

			s=g_malloc(strlen(yytext)-2); /*minus 3 and plus 1*/
			sscanf(yytext,"%d\\%[0-9a-zA-Z]s",&base,s);
			if(base>36) { g_free(s); REJECT; }
			mpw_init(yylval.val);
			mpw_set_str_int(yylval.val,s,base);
			g_free(s);
			DO_RET;
			return NUMBER;
		}

0x[0-9a-fA-F]+	|
0[0-7]+		|
[0-9]+		{
			mpw_init(yylval.val);
			mpw_set_str_int(yylval.val,yytext,0);
			DO_RET;
			return NUMBER;
		}
		
\\\n		{ incr_file_info(); }
		
[\t ]*\n	{ 
			incr_file_info();
			if(matrix_entry) {
				return NEXTROW;
			} else if(return_ret) {
				first_tok = 0;
				return '\n';
			}
		}
		
^[\t ][\t ]*	;

[\t ]*,[\t ]*	{ return ','; }

[\t][\t ]*	{
			if(matrix_entry)
				return ',';
		}

[ \t\r]+	; /*ignore whitespace*/

[!']		{
			DO_RET;
			return yytext[0];
		}

[@^*/%+-`]	{ NO_RET; return yytext[0]; }

\.		{ DO_RET; return '.'; }

\|		{ DO_RET; return '|'; }

<<EOF>>		{
			got_eof = TRUE;
			return '\n';
		}

.		{ NO_RET; return yytext[0]; }

%%

int my_yyinput(void);
int my_yyinput(void) { return input(); }