# Rich Text Format

In various place of the server, the Frama-C requests might return
rich-text format, which is text annotated with special tags,
for tagging or styling purpose.

The JSON encoding of rich-text is defined by the _text_ type, which takes one
of the following possible formats:

| Format | Description |
|:------:|:------------|
| `"null"` | Empty text |
| _string_ | Standard UTF-8 text |
| `[` (_tag_`,`)? _text_`,`…`,` _text_ `]` | Sequence of text with an optional tag |

Tags are simple strings, not to be printed, that encode the style or tag to
apply on the sequence. Tags starting with a sharp (`"#…"`) must be understood as
semantic tags, with a meaning depending on the context. Tags starting with
a dot (`".…"`) shall be understood as style names. Other values must be understand
as regular text.

The empty tag (`""`) shall be ignored, but can used to group sequence of text
together. Concatenation of sequence of text must be performed without any
spacing or cut in the between.

Text blocks can be nested. For instance, considerer the following JSON
encoding:

<pre>
[
  "This ",
  [
    "#frama-c-server-doc",
    "Frama", [ ".tt", "-C" ], " server"
  ],
  " is ", [ ".it", "awesome" ], " isn't it?"
]
</pre>

Provided the `#frama-c-server-doc` semantic is understood as a link to the
main page of the Frama-C server documentation, the designated rich-text
shall be printed as:

>  This [Frama-`C` server](../readme.md) is _awesome_ isn't it?

The precise meaning of styles and semantic tags might depends on the context,
and is detailed in each occurence of _text_ format.
