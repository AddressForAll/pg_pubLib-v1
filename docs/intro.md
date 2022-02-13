
PS: checking `\df round` after overloadings, will show something like,

<pre>
 Schema     |  Name | Result  | Argument  
------------+-------+---------+---------------
 myschema   | round | numeric | float, int
 pg_catalog | round | float   | float            
 pg_catalog | round | numeric | numeric   
 pg_catalog | round | numeric | numeric, int          
</pre>
Where *float* is synonymous of `double precision` and *myschema* is `public` when you not use a schema.  The `pg_catalog` functions are the default ones, see [manual of build-in math functions](https://www.postgresql.org/docs/current/functions-math.html).

### Note about performance and reuse

The build-in functions, such as ROUND of the pg_catalog, can be overloaded with no performance loss, when compared to direct cast encoding. Two precautions must be taken when implementing user-defined **cast functions for high performance**:

* The `IMMUTABLE` clause is very important for code snippets like this, because, as said in the Guide: *"allows the optimizer to pre-evaluate the function when a query calls it with constant arguments"*

* PLpgSQL is the preferred language, except for "pure SQL". For [JIT optimizations](https://www.postgresql.org/docs/current/jit-reason.html) (and sometimes for parallelism) SQL can obtain  better optimizations. Is something like copy/paste small piece of code instead of use a function call.

Conclusion: the above `ROUND(float,int)` function, after optimizations, is so fast than @CraigRinger's answer; it will compile to (exactly) the same internal representation. So, although it is not standard for PostgreSQL, it can be standard for your projects, by a centralized and reusable "library of snippets", like  [pg_pubLib](https://github.com/AddressForAll/pg_pubLib-v1).

## PLpgSQL optimization

As sayd in the official Guide, about the [Procedural Languages](https://www.postgresql.org/docs/current/xplang.html) and its interpretation,

> PostgreSQL allows user-defined functions to be written in other languages besides SQL and C. These other languages are generically called procedural languages (PLs). For a function written in a procedural language, the database server has no built-in knowledge about how to interpret the function's source text. Instead, the task is passed to a special handler that knows the details of the language.

And the Guide about [PLpgSQL interpreter](https://www.postgresql.org/docs/current/plpgsql-implementation.html#PLPGSQL-PLAN-CACHING),

> The PL/pgSQL interpreter parses the function's source text and produces an internal binary instruction tree the first time the function is called (within each session). The instruction tree fully translates the PL/pgSQL statement structure, but individual SQL expressions and SQL commands used in the function are not translated immediately.

> As each expression and SQL command is first executed in the function, the PL/pgSQL interpreter parses and analyzes the command to create a prepared statement, using the SPI manager's SPI_prepare function. Subsequent visits to that expression or command reuse the prepared statement. (...)
