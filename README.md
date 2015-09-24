# mesa

[![NPM Package](https://img.shields.io/npm/v/mesa.svg?style=flat)](https://www.npmjs.org/package/mesa)
[![Build Status](https://travis-ci.org/snd/mesa.svg?branch=master)](https://travis-ci.org/snd/mesa/branches)
[![Dependencies](https://david-dm.org/snd/mesa.svg)](https://david-dm.org/snd/mesa)

> simply elegant sql for nodejs

**this documentation targets the upcoming `mesa@1.0.0` release
currently in alpha and available on npm as `mesa@1.0.0-alpha.*`.**
**it's already used in production, is extremely useful, well tested
and quite stable !**

**mesa is a moving target. we are using it in production and it
grows and changes with the challenges it helps us solve.**

**`mesa@1.0.0` will be released when it's done !**

this documentation does not yet represent everything that is possible with mesa.
feel free to [look at the code](src/mesa.coffee). it's just around 600 lines.

[click here for documentation and code of `mesa@0.7.1` which will see no further development.](https://github.com/snd/mesa/tree/0.7.1)

## install

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

a call to `setConnection` is the (only) thing
tying/coupling the `database` mesa-object
to the node-postgres library and to the specific database.

## core ideas and configuration

calling `setConnection(callbackOrConnection)` has returned a new object.
the original mesa-object is not modified:

``` js
assert(database !== mesa);
```

**mesa embraces functional programming:
no method call on a mesa-object modifies that object.
mesa configuration methods are [pure](https://en.wikipedia.org/wiki/Pure_function):
they create a NEW mesa-object copy all OWN properties over to it,
set some property and return it.**

this has no effect:

``` js
mesa
  .setConnection(function(cb) {
    pg.connect('postgres://localhost/your-database', cb);
  });
```
it creates a new object that is not used anywhere and eventually gets garbage collected.

let's configure some tables:

``` js
var movieTable = database.table('movie');

var personTable = database.table('person');
```

there are no special database-objects, table-objects or query-objects in mesa.
only mesa-objects that all have the same methods.
order of configuration method calls does not matter.
you can change anything at any time:

``` js
var personTableInOtherDatabase = personTable
  .setConnection(function(cb) {
    pg.connect('postgres://localhost/your-other-database', cb);
  });
```

**it naturally follows that method calls on mesa-objects are chainable !**

``` js
var rRatedMoviesOfThe2000s = movieTable
  // `where` accepts raw sql and optional parameter bindings
  .where('year BETWEEN ? AND ?', 2000, 2009)
  // repeated calls to where are 'anded' together
  // `where` accepts objects that describe conditions
  .where({rating: 'R'});
```

### criterion

the `.where()` and `.having()` methods take **exactly** the same
arguments as criterion...

we can always get the SQL and parameter bindings of a mesa-object:

``` js
rRatedMoviesOfThe2000s.sql();
// -> 'SELECT * FROM "movie" WHERE (year BETWEEN ? AND ?) AND (rating = ?)'
rRatedMoviesOfThe2000s.params();
// -> [2000, 2009, 'R']
```

### mohair

mesa uses mohair to generate sql which it then sends to the database.
in addition to it's own methods every mesa-object has the entire interface
of a mohair-object.
for this reason the mohair methods are not documented in this readme.
consult the mohair documentation as well to get the full picture.

**mohair powers mesa's `.where`

### criterion

mesa's `.where` method is one such method that is implemented by mohair
mohair uses criterion

for this reason the criterion methods are not documented in this readme.

**criterion powers/documents mesa's `.where` and `.having`

we can refine:

``` js
var top10GrossingRRatedMoviesOfThe2000s = rRatedMoviesOfThe2000s
  .order('box_office_gross_total DESC')
  .limit(10);
```

**because every mesa-object gets a copy of all
a method added to a mesa-object
is available on all mesa-objects down the chain.**

this makes it very easy to extend the chainable interface...

``` js
movieTable.betweenYears = function(from, to) {
  return this
    .where('year BETWEEN ? AND ?', from to);
};

movieTable.page = function(page, perPage) {
  perPage = perPage ? perPage : 10;
  return this
    .limit(perPage)
    .offset(page * perPage);
};

var paginatedTopGrossingPG13RatedMoviesOfThe90s = movieTable
  // we can freely chain and mix build-in and custom methods !
  .order('box_office_gross_total DESC')
  .page(2)
  .where({rating: 'PG13'})
  .betweenYears(1990, 1999);
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

we can also simply check whether a query returns any records:

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

you can insert multiple records by passing multiple arguments and/or arrays
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

you see that mesa returns the inserted records by default

## update queries

This part is coming soon.

## delete queries

This part is coming soon.

## sql fragments

an sql fragment is any object with the following properties:

an sql([escape]) method which returns an sql string
takes an optional parameter escape which is a function to be used to escape column and table names in the resulting sql
a params() method which returns an array

at the heart of mesa is the query method

if you pass mesa (which is an sql fragment) into the query function...

## connections revisited

This part is coming soon.

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

you can add functions to the queues with the following ways

hooks either run on a the array of all items or item

array queues are run before 

functions in queues are run in the order they were added.

there are the following queues:

- `queueBeforeInsert` run before insert on array of items
- there is no `queueBeforeUpdate` because update always operates on a single item. use `queueBeforeEachUpdate`
- `queueBeforeEachInsert` run before insert on each item
- `queueBeforeEachUpdate` run before update on each item
- `queueBeforeEach` run before update or insert on each item

- `queueAfterSelect` run after find or first on array of items
- `queueAfterInsert` run after insert on array of items
- `queueAfterUpdate` run after update on array of items
- `queueAfterDelete` run after delete on array of items
- `queueAfter` run after find, first, insert, update and delete on array of items

- `queueAfterEachSelect` run after find or first on each item
- `queueAfterEachInsert` run after insert on each item
- `queueAfterEachUpdate` run after update on each item
- `queueAfterEachDelete` run after delete on each item
- `queueAfterEach` run after find, first, insert, update and delete on each item

### nice things you can to with queueing:

#### omit password property when a user is returned

``` js
var _ = require('lodash');

userTable
  .queueAfterEachSelect(_.omit, 'password')
  .where({id: 3})
  .first(function(user) {
  });
```

#### hash password before user is inserted or updated

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

#### convert property names between camelCase and snake_case

[see example/active-record.coffee](example/active-record.coffee)

#### set columns like `created_at` and `updated_at` automatically

``` js
userTable = userTable
  .queueBeforeEach(function(record) {
    record.updated_at = new Date();
    return record;
  })
  .queueBeforeInsert(function(record) {
    record.created_at = new Date();
    return record;
  });
```

#### fetch associated data

[see includes](#includes)

#### protect from mass assignment

mesa comes with a very powerful mechanism to manipulate
records before they are sent to the database or after they were received
from the database and before returning them.

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

**includes are a NEW feature and may not be as stable as the rest**

in any rows in different tables are linked via foreign keys.

includes make it easy to fetch those linked rows and add them to our data:

lets assume, for a moment, the following tables and relationships:

- `user` with columns `id`, `name`. has one `address`, has many `orders`
- `address` with columns `id`, `street`, `city`, `user_id`. belongs to `user` via foreign key `user_id` -> `user.id`
- `order` with columns `id`, `status`. belongs to `user`

``` js
userTable = database.table('user');
addressTable = database.table('address');
orderTable = database.table('order');
```

we can now find some users and include the orders in each of them:

### has many relationship

``` js
userTable
  .include(orderTable)
  .find(function(users) {

  })
```

a lot is happening here. let's break it down:

include has no side-effects and does not fetch any data.
instead it [queues](#queueing) a function to be executed
on all results (if any) of `first`, `find`, `insert`, `delete` and `update`
queries further down the chain.

in this case that function will
will run a query on `orderTable` to fetch all
orders where `order.user_id` is in the list of all `id` values in `users`.
it will then for every user add as property `orders` the list of all
orders where `user.id === order.user_id`.

**by default include queues a fetch of a has-many relationship**

the above code snippet is equivalent to this:

``` js
userTable
  .include({
    left: 'id',
    right: 'user_id',
    forward: true,
    first: false,
    as: 'orders'
  }, orderTable)
  .find(function(users) {

  })
```

the first argument to

in case that link-object is missing or any properties are missing (and only those fields)
mesa will autocomplete it from table names , primary keys set with `.primaryKey(key)`

### belongs to relationship

``` js
orderTable
  .include({forward: false, first: true}, userTable)
  .find(function(users) {

  })
```

### has many through

you can add as many additional link



you can modify, add conditions



you can nest






using an explicit link object:


**you get the idea**

includes are intentionally very flexible.
they work with any two tables where the values in 
whose values match up.

if you are using primary keys other than `id`

fetch a one-to-one association (in a single additional query)

the implementation uses the hooks
its surprisingly simple

using the same connection as the

use one additional query to fetch all 
and then associate them with the records

order and conditions and limits on the other tables have their full effects

## conditional

using mesa you'll often find yourself calling methods only
when certain conditions are met:

``` js
var dontFindDeleted = true;
var pagination = {page: 4, perPage: 10};

var tmp = userTable;

if (dontFindDeleted) {
  tmp = userTable.where({is_deleted: false});
}

if (pagination) {
  tmp = tmp
    .limit(pagination.perPage)
    .offset(pagination.page * pagination.perPage);
}

tmp.find(function(users) {
});
```

all those temporary objects are not very nice.

fortunately there is another way:

``` js
userTable
  .when(dontFindDeleted, userTable.where, {is_deleted: false})
  .when(pagination, function() {
    return this
      .limit(pagination.perPage)
      .offset(pagination.page * pagination.perPage);
  })
  .find(function(users) {
  });
```

## contribution

**TL;DR: bugfixes, issues and discussion are always welcome.
ask me before implementing new features.**

i will happily merge pull requests that fix bugs with reasonable code.

i will only merge pull requests that modify/add functionality
if the changes align with my goals for this package
and only if the changes are well written, documented and tested.

**communicate:** write an issue to start a discussion
before writing code that may or may not get merged.

## [license: MIT](LICENSE)
