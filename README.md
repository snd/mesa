# mesa

[![NPM Package](https://img.shields.io/npm/v/mesa.svg?style=flat)](https://www.npmjs.org/package/mesa)
[![Build Status](https://travis-ci.org/snd/mesa.svg?branch=master)](https://travis-ci.org/snd/mesa/branches)
[![Dependencies](https://david-dm.org/snd/mesa.svg)](https://david-dm.org/snd/mesa)

> simply elegant sql for nodejs:
build and execute queries, manage connections


mesa is an immensely useful and pragmatic

as simple as possible.

**this documentation targets the upcoming `mesa@1.0.0` release
currently in alpha and available on npm as `mesa@1.0.0-alpha.*`.**
**it's already used in production, is extremely useful, well tested
and quite stable !**
**this documentation does not yet represent everything that is possible with mesa.**
**`mesa@1.0.0` will be released WHEN IT'S DONE !**

[click here for documentation and code of `mesa@0.7.1` which will see no further development.](https://github.com/snd/mesa/tree/0.7.1)

## introduction

install latest:

```
npm install --save mesa
```

mesa needs [node-postgres](https://github.com/brianc/node-postgres):

```
npm install --save pg
```

require both:

``` js
var mesa = require('mesa');
var pg = require('pg');
```

## connections

let's tell mesa how to get a database connection for a query:

``` js
var database = mesa
  .setConnection(function(cb) {
    pg.connect('postgres://localhost/your-database', cb);
  });
```

a call to `setConnection` is the only thing tying the `database` mesa-object
to the node-postgres library and to the specific database.

## core ideas and configuration

calling `setConnection(callbackOrConnection)` has returned a new object.
the original `mesa` object is not modified:

``` js
assert(database !== mesa);
```

**mesa embraces functional programming:
no method call on a mesa-object modifies that object.
mesa configuration methods are [pure](https://en.wikipedia.org/wiki/Pure_function):
they create a new mesa-object that prototypically inherits from the one before it,
set some property on the new object and return the new object.**

let's configure some tables:

``` js
var movieTable = database.table('movie');

var personTable = database.table('person');
```

there are no special database-objects, table-objects or query-objects in mesa.
only mesa-objects that all have the same methods.
order of configuration method calls does not matter.
you can change everything at any time:

``` js
var personTableInOtherDatabase = personTable
  .setConnection(function(cb) {
    pg.connect('postgres://localhost/your-other-database', cb);
  });
```

from the above properties follows that **method calls on mesa-objects can be chained !**.

``` js
var rRatedMoviesOfThe2000s = movieTable
  // `where` accepts raw sql + optional parameter bindings
  .where('year BETWEEN ? AND ?', 2000, 2009)
  // repeated calls to where are 'anded' together
  // `where` accepts objects that describe conditions
  .where({rating: 'R'});
```

the `.where()` and `.having()` methods take **exactly** the same
arguments as criterion...

we can always get the SQL and parameter bindings of a mesa-object:

``` js
rRatedMoviesOfThe2000s.sql();
// -> 'SELECT * FROM "movie" WHERE (year BETWEEN ? AND ?) AND (rating = ?)'
rRatedMoviesOfThe2000s.params();
// -> [2000, 2009, 'R']
```

we can refine 
mesa builds on top of mohair
consult mohair 

``` js
var top10GrossingRRatedMoviesOfThe2000s = rRatedMoviesOfThe2000s
  .order('box_office_gross_total DESC')
  .limit(10);
```

**mesa embraces prototypical inheritance:
because every mesa-object prototypically inherits from the one before it
a method added to a mesa-object
is available on all mesa-objects down the chain - this is huge ! :**

``` js
movieTable.inYearRange = function(from, to) {
  return this
    .where('year BETWEEN ? AND ?', from to);
};

movieTable.page = function(page, perPage) {
  perPage = perPage ? perPage : 10;
  return this
    .limit(perPage)
    .offset(page * perPage);
};

var top3GrossingPG13RatedMoviesOfThe90s = movieTable
  // we can freely chain and mix build-in and custom methods !
  .order('box_office_gross_total DESC')
  .page(2)
  .where({rating: 'PG13'})
  .whereInYearRange(1990, 1999);
```

**we see how pure functions and immutability lead to simplicity, reusability
and [composability](#composability) !**

## select queries

we can run a select query on a mesa object and return all results:

``` js
top10GrossingRRatedMoviesOfThe2000s
  // run a select query and return all results
  .find()
  // running a query always returns a promise
  .then(function(top10Movies) {
  });
```

**running a query always returns a promise !**

we can run a select query on a mesa object and return only the first result:

``` js
top10GrossingRRatedMoviesOfThe2000s
  // run a select query and return only the first result
  // `first` automatically calls `.limit(1)` to be as efficient as possible
  .first()
  // running a query always returns a promise
  .then(function(topMovie) {

  });
```

we can also simply check whether a record exists:

``` js
movieTable
  .where({name: 'Moon'})
  .exists()
  // running a query always returns a promise
  .then(function(exists) {

  });
```

## insert queries

we can run an insert query on a mesa object:

``` js
movieTable
  // whitelist some properties to prevent mass assignment
  .allow('name')
  .insert({name: 'Moon'})
  // running a query always returns a promise
  // if insert is called with a single object only the first inserted object is returned
  .then(function(insertedMovie) {
  })
```

before running insert queries

if you have control over the properties of the inserted objects
and can ensure that no properties
can disable this by calling `.unsafe()`.
you can reenable it by calling `.unsafe(false)`.

you can insert multiple records by massing multiple arguments and/or arrays
to insert:

``` js
movieTable
  // disable mass-assignment protection
  .unsafe()
  // running a query always returns a promise
  .insert(
    {name: ''}
    [
      {name: ''}
      {name: ''}
    ]
    {name: ''}
  )
  .then(function(insertedMovies) {
  })
```

## update queries

## delete queries

## connections revisited

## queueing

## including

## connections revisited

``` js
```

`setConnection` either accepts

`wrapInConnection`

all of sql

down to the metal

## debugging

``` js
mesaWithDebug = mesa.debug(function( , detail, state, verboseState, instance)
```

only on refined versions

intermediary results

debugging per table, per query, ...

directly before a query debug will just for that specific query

just display sql

``` js
mesa = mesa.debug(function(topic, query, data)
  if (topic === 'query' && event === 'before') {
    console.log('QUERY', data.sql, data.params);
  }
});
```

the topics are `connection`, `query`, `transaction`, `find`, `embed`

that function will be called with five arguments

the first argument is 

the fifth argument is the instance

the fourth argument contains ALL additional local state that is `connection, arguments`

here is a quick overview:

look into the source to see exactly which 



## queueing

often you want to for all tables, a specific table
a specific 
do something to the records

you can `configure` mesa instances.

mesa comes with a very powerful mechanism to manipulate
records before they are sent to the database or after they were received
from the database and before returning them.

mesa uses the queueing mechanism itself for [mass assignment protection]() and for [embedding associated data]()

see the appendix for useful examples

[hash passwords](#hash-passwords)

``` js
var Promise = require('bluebird');
var bcrypt = Promise.promisifyAll(require('brypt'));

var hashPassword = function(record) {
  if (record.password) {
    bcrypt.genSaltAsync(10).then(function(salt) {
      return bcrypt.hashAsync(password, salt);
    });
  } else {
    return Promise.resolve(null);
  };
}

userTable = userTable.queueBeforeEach(hashPassword);
```

now the user table

``` js
var immutable = require('immutable');

var fromImmutable(

userTable
  .beforeEach('fromImmutable', fromImmutable)
  .afterEach('toImmutable', toImmutable)
  .order('hashPassword', 'toImmutable')
user
```

``` js
var _ = require('lodash');

  .queueAfterEachSelect(_.omit, 'password')
```

using hooks you can simulate the active record pattern like this:

mesa uses the data mapper pattern

mesa is the mapper

and the data is just plain java objects


if you are familiar with the active record pattern
prefer a more object-oriented style
here is how you would use mesa to implement it
as the foundation
as the building blocks


if you want to use camelcased property names in your program
and underscored in your database you can automate the translation

```


```

add them to the mesa instance and have it work for all your tables

by setting the order you ensure that the other hooks see
camelcased properties !!!

## includes

fetch a one-to-one association (in a single additional query)

the implementation uses the hooks
its surprisingly simple

using the same connection as the

does not fetch the association right away
neither does it set some 
instead it uses the hooks to queue that associations be
fetched after a find, first, delete and update.

use one additional query to fetch all 
and then associate them with the records

order and conditions and limits on the other tables have their full effects

``` js
commentTable
  .belongsTo({
    table: userTable, // REQUIRED
    fk: 'user_id', // foreign key, default '{table.name}_id'
    pk: 'id', // primary key, default 'id'
    as: 'user' // property name, default '{table.name}'
  })
  .find()
  .then(function(comments) {
    // comments[0].user -> fetched user record
  })
```

you can add your own conditions to associations

fetch only not-deleted associated

``` js
commentTable
  .queueBelongsTo({
    table: userTable.where(is_deleted: false)
  })
  .find()
  .then(function(comments) {
    // comments[0].user -> fetched user record
  })
```

one to many:

``` js
userTable
  .queueEmbedHasMany({
    table: commentTable, // REQUIRED
    pk: 'id', // primary key, default 'id'
    fk: 'user_id', // foreign key, default '{this.getTable()}_id'
    as: 'comments' // property name, default '{table.getTable()}s'
  })
  .find()
  .then(function(comments) {

  })
```

has-one and belongs-to relationships can also be fetched
in a single query by using a join.

``` js
var userColums = [
  'first_name',
  'last_name',
  'birthday'
];

var userPrefix = 'user_';

userTable
  .select('*', userColumns.map(function(x) {
    var mapping = {}
    mapping[userPrefix] = 'user.' + x;
    return mapping;
  })
  .join(
    type: 'left'
    table: 'user' or subquery
    where:

  )
  // mergePrefixed
  // collapsePrefixed
  .queueMergePrefixed({
    prefix: userPrefix
    as: 'user' // default prefix.slice(0, -1)
  })
  .find(
```

thats mesa

read the principles or the detailed reference by example.

motivating example

you can nest embeds.

## why just postgres?

we are just using postgres, not mysql, not sqlite.

## [license: MIT](LICENSE)

