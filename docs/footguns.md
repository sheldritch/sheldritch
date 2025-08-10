# Footguns

Tools you can use to shoot yourself in the foot.

Or: traps to avoid.


## Literal/Variable ambiguity

Let's say you have a command `foo` with the usage string
`Usage='SUPERSET... contains SUBSET...'`, that returns successfully when all
arguments in SUBSET are also arguments in SUPERSET. So `foo A B C contains A C`
succeeds but `foo A B C contains A Z` fails. What if someone calls the
following?

```bash
foo contains contains contains contains contains
```

Which `contains` is the literal one from the usage string?

This is a really big issue in this use case, because every call with `contains`
deals with unknown data. If you already knew what each side contains, you
wouldn't need to run the command in the first place. So in practical use,
whenever someone uses the command, they are never going to know whether or not
their use of the command will have `contains` in the input, without doing extra
work beforehand to find out.

This is a common problem in even simple command-line interfaces. If you have a
file `-f` you want to delete, `rm -f` will interpret it as a flag. The common
solution is to have an escape argument `--` which no following arguments should
be interpreted as flags. It's a hard delimiter that removes ambiguity. And if
you want to delete the file `--`, you can do `rm -- --`.

But we have an extra problem, because `contains` (the user parameter) may
potentially appear on either side of the operator `contains`. We can throw an
error if `contains` appears as an argument twice, but there's no clear way for
the user to identify 'before' and 'after'.


This is the same problem as string delimitation (I mean, it is a string
delimitation issue, just a string of args instead of chars).

In this particular use case, if you wanted to call `foo` on arbitrary user
input, you could preprocess the input like so:

```bash
# Assuming you have elements stored in two arrays to test
foo "${SuperSet[@]//contains/containscontains}" contains "${SubSet[@]//contains/containscontains}"
```

Doubling the value . Note this won't work if the literal is repeating -- 
literal instead of `contains` may h

Note that if you wanted to deal with reversing this hack 

abaaba
