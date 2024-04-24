/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

/* --- Generated Frama-C Server API --- */

/**
   Informations
   @packageDocumentation
   @module frama-c/kernel/api/data
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


/** Markdown (inlined) text. */
export type markdown = string;

/** Decoder for `markdown` */
export const jMarkdown: Json.Decoder<markdown> = Json.jString;

/** Natural order for `markdown` */
export const byMarkdown: Compare.Order<markdown> = Compare.string;

/** Default value for `markdown` */
export const markdownDefault: markdown = '';

/** Rich text format uses `[tag; …text ]` to apply the tag `tag` to the enclosed text. Empty tag `""` can also used to simply group text together. */
export type text = null | string | text[];

/** Decoder for `text` */
export const jText: Json.Decoder<text> =
  (_x: any) => Json.jUnion<null | string | text[]>(
                 Json.jNull,
                 Json.jString,
                 Json.jArray(jText),
               )(_x);

/** Natural order for `text` */
export const byText: Compare.Order<text> =
  (_x: any, _y: any) => Compare.structural(_x,_y);

/** Default value for `text` */
export const textDefault: text = null;

/** Enum Tag Description */
export type tag = { name: string, label: markdown, descr: markdown };

/** Decoder for `tag` */
export const jTag: Json.Decoder<tag> =
  Json.jObject({ name: Json.jString, label: jMarkdown, descr: jMarkdown,});

/** Natural order for `tag` */
export const byTag: Compare.Order<tag> =
  Compare.byFields
    <{ name: string, label: markdown, descr: markdown }>({
    name: Compare.alpha,
    label: byMarkdown,
    descr: byMarkdown,
  });

/** Default value for `tag` */
export const tagDefault: tag =
  { name: '', label: markdownDefault, descr: markdownDefault };

/* ------------------------------------- */
