/*_ filespec.h   Fri Jul  8 1988   Modified by: bright */
/* Copyright (C) 1986-1987 by Northwest Software        */
/* All Rights Reserved                                  */
/* Written by Walter Bright                             */
module dmd.backend.filespec;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.mem;


nothrow:
@safe:

version (Windows)
{
    enum DIRCHAR = '\\';

    bool ispathdelim(char c) { return c == DIRCHAR || c == ':' || c == '/'; }
}
else
{
    enum DIRCHAR = '/';

    bool ispathdelim(char c) { return c == DIRCHAR; }
}

/**********************
 * Return string that is the dot and extension.
 * The string returned is NOT mem_malloc'ed.
 * Return pointer to the 0 at the end of filespec if dot isn't found.
 * Return NULL if filespec is NULL.
 */
@trusted
char *filespecdotext(const(char)* filespec)
{
    auto p = filespec;
    if (p)
    {
        const len = strlen(p);
        p += len;
        while (1)
        {
            if (*p == '.')
                break;
            if (p <= filespec || ispathdelim(*p))
            {   p = filespec + len;
                break;
            }
            p--;
        }
    }
    return cast(char*)p;
}

/***********************
 * Get root name of file name.
 * That is, return a mem_strdup()'d version of the filename without
 * the .ext.
 */

char *filespecgetroot(const(char)* name)
{
    char* p = filespecdotext(name);
    const c = *p;
    *p = 0;
    char* root = mem_strdup(name);
    *p = c;
    return root;
}

/**********************
 * Return string that is the filename plus dot and extension.
 * The string returned is NOT mem_malloc'ed.
 */

@trusted
char *filespecname(const(char)* filespec)
{
    const(char)* p;

    /* Start at end of string and back up till we find the beginning
     * of the filename or a path
     */
    for (p = filespec + strlen(filespec);
         p != filespec && !ispathdelim(*(p - 1));
         p--
        )
    { }
    return cast(char *)p;
}
