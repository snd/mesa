# mesa

[![NPM Package](https://img.shields.io/npm/v/mesa.svg?style=flat)](https://www.npmjs.org/package/mesa)
[![Build Status](https://travis-ci.org/snd/mesa.svg?branch=master)](https://travis-ci.org/snd/mesa/branches)
[![Dependencies](https://david-dm.org/snd/mesa.svg)](https://david-dm.org/snd/mesa)

> simply elegant sql for nodejs:
build and execute queries, manage connections

**this documentation targets the upcoming `1.0.0` release of mesa,
currently in alpha and available on npm as [`mesa@1.0.0-alpha.11`](https://www.npmjs.org/package/mesa)**

**this documentation is a work in progress**

- [in a nutshell](#in-a-nutshell)
- [principles](#principles)
- [functional programming](#functional-programming)
- [mohair](#mohair)
- [criterion](#criterion)
- [connections](#connections)
- [handling data](#handling-data)
- [embedding associated data](#embedding-associated-data)

## in a nutshell (or quick tour)

install

```
npm install --save mesa@1.0.0-alpha.10
```

mesa needs [node-postgres](https://github.com/brianc/node-postgres)

```
npm install --save pg
```

tell mesa how to get a connection from [node-postgres](https://github.com/brianc/node-postgres)

``` js
var mesa = require('mesa');
var pg = require('pg');

var connectedMesa = mesa.setConnection(function(cb) {
  pg.connect('postgres://localhost/your-database', cb);
});
```

mesa is configured through a
[fluent](http://en.wikipedia.org/wiki/Fluent_interface) (chainable) API.

``` js
var movieTable = connectedMesa.table('movie');
```

select





functional style: pure functions, no data mutation:
simple, reusable, composable !

``` js
var cancelledFlights = flightTable
  .where({is_cancelled: true})

var lastCancelledFlights = cancelledFlights
  .order({cancelled_at: 'DESC'})
  .limit(100);

cancelledFlights.sql();
// -> 'SELECT * FROM "flight" where "is_cancelled" = ? ORDER BY "cancelled_at" DESC LIMIT ?'
cancelledFlights.params();
// -> [true, 100]
```

subqueries


all of sql

down to the metal


promises

powerful 

``` js
var cancelledFlightsPromise = cancelledFlights.find();

cancelledFlightsPromise.then(function(flights) {
  // ...
});

flightTable
  .allow('
  .insert({

  })
  .then(function(inserted) {
    // ...
  });
```

## configuration

global configuration
table configuration
chain configuration (association chain) TODO better name
query configuration

lets call this an instance.

refining



repeated calls: merge or overwrite


## debugging

> debug lets you see inside mesa's operations

``` js
mesa.debug(function( , detail, state, verboseState, instance) 
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


## extending

paginate


extending for associations

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

``` js
var _ = require('lodash');

// constructor

var Table = function() {
};

Table.prototype =
  save: function() {
    if (this.id) {
      userTable.where({id: this.id})
      .returnFirst()
      .update(this)
      .then (data)
        _.assign(this, data);
    } else {
      _.assign(this, data);

    }
  },
  delete: function() {

  }

var User = function(data) {
  _.assign(this, data);
}

User.prototype = Object.create(Table.prototype);

// table

var userTable = connectedMesa
  .table('user')
  .queueAfterEachSelect(function(record) {
    return new User(record);
  });

// static methods

User.firstWhereFirstName = function(firstName) {
  return userTable.where({first_name: firstName}).first();
};

// ...

// instance methods

User.prototype = {
// getters
  name: function() {
    return this.first_name + this.last_name;
  },
  age: function() {
    return moment().diff(this.birthday, 'years');
  }
};

// use it

User.firstWhereFirstName('alice').then(function(user) {
  user.firstName = 'bob';
  user.save().then(function(user) {
    assert(user.name, 'bob');
  });
});

```

if you want to use camelcased property names in your program
and underscored in your database you can automate the translation

```


```

add them to the mesa instance and have it work for all your tables

by setting the order you ensure that the other hooks see
camelcased properties !!!

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

## background

mesa is not an orm. it aims to help as much as possible with the construction, composition and execution of sql queries
while not restricting full access to the underlying database driver and database in any way.

mesa builds on top of [mohair, a simple fluent sql query builder](https://github.com/snd/mohair).

it adds the ability to run queries on connections, process query results, to declare and include
associations (`hasOne`, `belongsTo`, `hasMany`, `hasManyThrough`) and more.

mesa has been battle tested in a medium sized (8 heroku dynos) production environment
for half a year.

mesa uses criterion for sql-where-conditions.
consult the [criterion readme](https://github.com/snd/criterion)
and [mohair readme](https://github.com/snd/mohair) to get the full picture of what is possible with mesa.

### use

mesa has a fluent interface where every method returns a new object.
no method ever changes the state of the object it is called on.
this enables a functional programming style.

#### require

```javascript
var mesa = require('mesa');
```

#### connections

tell mesa how to get a connection from the pool:

```javascript
var pg = require('pg');

var mesaWithConnection = mesa.connection(function(cb) {
    pg.connect('tcp://username@localhost/database', cb);
});

```

`mesaWithConnection` will now use the provided function to get connections
for the commands you execute.
these connections are under mesa's control.
mesa will [properly call done()](https://github.com/brianc/node-postgres/wiki/pg#connectfunction-callback) on every connection it has obtained from the
pool.

#### tables

specify the table to use:

```javascript
var userTable = mesaWithConnection.table('user');
```

#### command

##### insert

```javascript
userTable.
    .attributes(['name'])
    .insert({
        name: 'alice'
    }, function(err, id) {
    });
```

`attributes()` sets the properties to pick from data in the `create()` and `update()`
methods. `attributes()` prevents mass assignment
and must be called before using the `create()` or `update()` methods.

##### insert multiple records

```javascript
userTable
    .attributes(['name'])
    .insertMany([
        {name: 'alice'},
        {name: 'bob'}
    ], function(err, ids) {
    });
```

##### insert with some raw sql

```javascript
userTable.
    .attributes(['name', 'created'])
    .insert({
        name: 'alice',
        created: userTable.raw('NOW()')
    }, function(err, id) {
    });
```

`raw()` can be used to inject arbitrary sql instead of binding a parameter.

##### delete

```javascript
userTable.where({id: 3}).delete(function(err) {
});
```

see the [criterion readme](https://github.com/snd/criterion) for all the ways to
specify where conditions in mesa.

##### update

```javascript
userTable
    .where({id: 3})
    .where({name: 'alice'})
    .update({name: 'bob'}, function(err) {
    });
```

multiple calls to `where` are anded together.

#### query

##### find the first

```javascript
userTable.where({id: 3}).first(function(err, user) {
});
```

##### test for existence

```javascript
userTable.where({id: 3}).exists(function(err, exists) {
});
```

##### find all

```javascript
userTable.where({id: 3}).find(function(err, user) {
});
```

##### select, join, group, order, limit, offset

```javascript
userTable
    .select('user.*, count(project.id) AS project_count')
    .where({id: 3})
    .where('name = ?', 'foo')
    .join('JOIN project ON user.id = project.user_id')
    .group('user.id')
    .order('created DESC, name ASC')
    .limit(10)
    .offset(20)
    .find(function(err, users) {
    });
```

#### associations

##### has one

use `hasOne` if the foreign key is in the other table (`addressTable` in this example)

```javascript
var userTable = userTable.hasOne('address', addressTable, {
    primaryKey: 'id',               // optional with default: 'id'
    foreignKey: 'user_id'           // optional with default: userTable.getTable() + '_id'
});
```

the second argument can be a function which must return a mesa object.
this can be used to resolve tables which are not yet created when the association
is defined.
it's also a way to do self associations.

##### belongs to

use `belongsTo` if the foreign key is in the table that `belongsTo`
is called on (`projectTable` in this example)

```javascript
var projectTable = projectTable.belongsTo('user', userTable, {
    primaryKey: 'id',               // optional with default: 'id'
    foreignKey: 'user_id'           // optional with default: userTable.getTable() + '_id'
});
```

##### has many

use `hasMany` if the foreign key is in the other table (`userTable` in this example) and
there are multiple associated records

```javascript
var userTable = userTable.hasMany('projects', projectTable, {
    primaryKey: 'id',               // optional with default: 'id'
    foreignKey: 'user_id'           // optional with default: userTable.getTable() + '_id'
});
```

##### has many through

use `hasManyThrough` if the association uses a join table

```javascript
var userProjectTable = mesaWithConnection.table('user_project');

var userTable = userTable.hasManyThrough('projects', projectTable, userProjectTable,
    primaryKey: 'id',               // optional with default: 'id'
    foreignKey: 'user_id',          // optional with default: userTable.getTable() + '_id'
    otherPrimaryKey: 'id',          // optional with default: 'id'
    otherForeignKey: 'project_id'   // optional with default: projectTable.getTable() + '_id'
});
```

### advanced use

##### extending mesa's fluent interface

every mesa object prototypically inherits from the object
before it in the fluent call chain.

this means that every mesa object is very lightweight since
it shares structure with objects before it in the fluent call chain.

it also makes it very easy to extend mesa's fluent interface:

```javascript
var userTable = mesa.table('user');

userTable.activeAdmins = function() {
    return this.where({visible: true, role: 'admin'});
};

userTable.whereCreatedBetween = function(from, to) {
    return this.where('created BETWEEN ? AND ?', from, to);
};

userTable
    .order('created DESC')
    .activeAdmins()
    .whereCreatedBetween(new Date(2013, 4, 10), new Date(2013, 4, 12))
    .find(function(err, users) {
    });
```

##### user controlled connections

sometimes, when using a transaction, you need to run multiple commands over multiple tables on the
same connection.

use `getConnection()` to get a raw connection from mesa.
you can then run arbitrary sql on that connection.
use `connection()` with a connection object to
tell mesa to explicitely use that connection instead of getting
a new one from the pool:

```javascript
userTable.getConnection(function(err, connection, done) {
    connection.query('BEGIN', function(err) {
        userTable
            // use the transactional connection explicitely
            .connection(connection)
            .insert({name: 'alice'}, function(err, id) {

                // run more commands in the transaction
                // possibly on other tables

                connection.query('COMMIT', function(err) {
                    done();
                });
            });
    });
});
```

when you are done using the connection you need to call `done()` to
tell node-postgres to return the connection to the pool.
otherwise you will leak that connection, which is **very bad** since
your application will run out of connections and hang.


- `pgCallbackConnection(cb)` connects to `blaze_config_databaseUrl`
   and calls `cb(connection, error, done)`
- `pgConnection()` -> `Promise({connection: ..., done: ...})`
   connects to `blaze_config_databaseUrl`
   and returns promise containing `connection` and `done` callback
- `pgQuery(connection, sql, [params])` -> `Promise(queryResult)`
   runs query on connection
- `pgWrapInConnection(function(connection) {function body that uses connection})` -> `Promise returned by function`
   connects to `blaze_config_databaseUrl`,
   calls function with connection,
   closes connection
- `pgSingleQuery(sql, params)` -> `Promise(queryResult)`
   connects to `blaze_config_databaseUrl`,
   runs query, closes connection
- `pgWrapInTransaction(function(connection) {function body that uses connection})` -> `Promise returned by function`
   connects to `blaze_config_databaseUrl`,
   begins transactions
   calls function with connection,
   rolls transaction back if function throws or returns promise that is rejected,
   commits transaction otherwise,
   closes connection in any case


## changelog

### 

## [license: MIT](LICENSE)

## TODO

- real world test database
  - movies

- integration tests for embeds

- fix mohair to make travis tests work

- do not side effect function arguments (options)
- make sure that every function is exercised
- test functions in more isolation !!!
- expand active records integration test

- unit test that escape works with schemas
- test those really hardcore scenarios with mesas integration tests
  - which ones?
- improve keywords in package.json

#mesa

mesa is just query execution

it uses promises to manage async code


there are two kinds of functions: fluent and endpoints.
fluent return a new mesa instance which prototypically inherits.
endpoints return a promise.
getters return some information: sql(), params(), mesa.info()
both don’t change the mesa instance !

connection management
queries
dealing with data records that are inserted and selected
functional style

define functions to be run before and after queries

info():
mohair.info()
explicit connection or not
steps
execution order

// runs for each record
// runs for the entire collection

before key
beforeInsertRecord
beforeUpdateRecord

beforeCollection
beforeInsertCollection

you can unset by calling removeBeforeCollection(‘foo’)
you can overwrite by calling again

afterRecord
afterCollection

afterRecordInsert

afterCollectionInsert

afterRecordDelete

you can call removeBeforeInsert(‘pick-allowed’) to disable it

all steps are called with the mesa instance as `this`

afterDeleteArray key

replace placeholders in escape function and in .sql()


steps to be done with the data

write examples for use cases into readme

use cases:

filter data / prevent mass assignment
convert to/from Facebook immutable data and/or mori data
auto set created_at / updated_at timestamps
hash passwords
omit sensitive data (passwords) from outputs
fetch and embed associated data
auto convert from camel case to underscore and vice versa
wrap data in instances


“rohr” or cathode


merge

provide as many embed helpers as needed

hooks play super nice with promises





order(foo: ‘desc’) (is a mohair thing)
