# mesa

[![Build Status](https://travis-ci.org/snd/mesa.png)](https://travis-ci.org/snd/mesa)

**simple elegant sql for nodejs**

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

### install

```
npm install mesa
```

### use

mesa has a fluent interface where every method returns a new object.
no method ever changes the state of the object it is called on.
this enables a functional programming style.

#### require

```javascript
var mesa = require('mesa');
```

#### connections

**mesa only works with [node-postgres](https://github.com/brianc/node-postgres) at the moment**

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

##### including associated

associations are only fetched if you `include` them:

```javascript
userTable.includes({address: true}).find(function(err, users) {
});
```

includes can be nested arbitrarily deep:

```javascript
userTable
    .includes({
        shipping_address: {
            street: true,
            town: true
        },
        billing_address: true,
        friends: {
            billing_address: true
    }})
    .find(function(err, users) {
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

### license: MIT
