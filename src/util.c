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

#include "config.h"

#ifdef GNOME_SUPPORT
#include <gnome.h>
#else
#include <libintl.h>
#define _(x) gettext(x)
#endif
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "util.h"

void *
my_malloc(size_t size)
{
	return g_malloc(size);
}

/*simple realloc/free functions using g_malloc/g_free confogming to gmp*/
void *
my_realloc(void *ptr,size_t olds,size_t news)
{
	void *p;
	
	if(news<=0) /*what kind of request would that be*/
		return NULL;

	p=g_malloc(news);
	if(!p) {
		if(ptr) g_free(ptr);
		return NULL;
	}

	if(ptr && olds>0) {
		if(news<olds)
			memcpy(p,ptr,news);
		else
			memcpy(p,ptr,olds);
		g_free(ptr);
	} else			/*in case it's a string and original was NULL*/
		*(char *)p='\0';/*make an empty string*/
	return p;
}

void
my_free(void *ptr,size_t s)
{
	g_free(ptr);
}


/*shift the sring to the right by n*/
void
shiftstr(char *s,int n)
{
	char *p;
	if(!s || n<=0)
		return;
	/*copies \0 as well*/
	for(p=s+strlen(s);p>=s;p--)
		*(p+n)=*p;
}

/*allocate new space in s for p and append it*/
char *
appendstr(char *s,char *p)
{
	if(s) {
		s=my_realloc(s,strlen(s)+1,strlen(s)+strlen(p)+1);
		strcat(s,p);
	} else {
		s=(char*)g_malloc(strlen(p)+1);
		strcpy(s,p);
	}
	return s;
}

/*allocate new space in s for p and prepend it*/
char *
prependstr(char *s,char *p)
{
	char *p2;
	if(s) {
		p2=(char *)g_malloc(strlen(s)+strlen(p)+1);
		strcpy(p2,p);
		strcat(p2,s);
		g_free(s);
		return p2;
	}
	s=(char*)g_malloc(strlen(p)+1);
	strcpy(s,p);
	return s;
}



void
stack_push(GSList **stack, gpointer data)
{
	g_return_if_fail(stack);
	*stack = g_slist_prepend(*stack,data);
}

gpointer
stack_pop(GSList **stack)
{
	gpointer data;
	GSList *p;

	g_return_val_if_fail(stack,NULL);

	if(*stack == NULL) {
		g_warning(_("Stack underflow!"));
		return NULL;
	}

	data = (*stack)->data;
	p = (*stack)->next;
	g_slist_free_1(*stack);
	*stack = p;
	return data;
}

char *
unescape_string(char *s,char *end,char *nounescape)
{
	char *n;
	char *p;
	
	g_return_val_if_fail(s!=NULL,NULL);
	
	n = p = g_new(char,strlen(s)+1);

	while(*s && (!end || s<end)) {
		if(*s == '\\' && *(s+1) && (!end || (s+1)<end)) {
			switch(*(s+1)) {
			case 'n': *(p++) = '\n'; break;
			case 't': *(p++) = '\t'; break;
			case 'b': *(p++) = '\b'; break;
			case 'r': *(p++) = '\r'; break;
			case 'a': *(p++) = '\a'; break;
			default:
				if(nounescape) {
					if(strchr(nounescape,*(s+1)))
						*(p++) = '\\';
					*(p++) = *(s+1);
				} else 
					*(p++) = *(s+1);
				break;
			}
			s+=2;
		} else
			*(p++)=*(s++);
	}
	*p = '\0';
	return n;
}

/*escape also "'s and \'s*/
char *
escape_string(char *s)
{
	char *n;
	char *p;
	int i;
	
	g_return_val_if_fail(s!=NULL,NULL);
	
	for(i=0,p=s;*p;p++) {
		switch(*p) {
		case '\n':
		case '\t':
		case '\b':
		case '\r':
		case '\a':
		case '"':
		case '\\': i++; break;
		default: ;
		}
	}
	
	n = p = g_new(char,strlen(s)+i+1);

	while(*s) {
		switch(*s) {
		case '\n':
			*(p++) = '\\'; *(p++) = 'n'; s++; break;
		case '\t':
			*(p++) = '\\'; *(p++) = 't'; s++; break;
		case '\b':
			*(p++) = '\\'; *(p++) = 'b'; s++; break;
		case '\r':
			*(p++) = '\\'; *(p++) = 'r'; s++; break;
		case '\a':
			*(p++) = '\\'; *(p++) = 'a'; s++; break;

		case '"':
		case '\\': 
			*(p++) = '\\';
		default: ; *(p++)=*(s++);
			 break;
		}
	}
	*p = '\0';
	return n;
}