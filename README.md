# mesa

- is a sensible abstraction which makes most of operations extremely
- base for your models
- makes most operations extremely easy
- let's you do everything else
 while still letting
- is not an orm
- is flexible
- works only with postgres

real world needs

### immutability

mesa objects are immutable.
no method call ever changes the state of the mesa object it is called on.

every call to a chainable configuration method (`table`, `connection`, `attributes`, `where`, ...)
returns a new mesa object.

### install

```
npm install mesa
```

### configure

```coffeescript
pg = require 'pg'
Model = require 'mesa'

getConnection = (cb) -> pg.create 'tcp://foo@localhost/bar', cb

# the user object will be used in all following examples
user = new Model()
    .table('user')
    .connection(getConnection)
    .attributes(['name', 'email'])
```

`connection()` either takes a connection object or a function, which is supposed to take a
callback and call it with a connection object.
providing a connection object explictely is useful when you use transactions.

`attributes` sets the keys to pick from data in `create` and `update`
you have to call it before you use `create` or `update`

### command

##### insert

```coffeescript
user.insert {
    name: 'foo'
}, (err, userId) -> # ...
```

##### insert multiple records

```coffeescript
user.insert [
    {name: 'foo'}
    {name: 'bar'}
], (err, userIds) -> # ...
```

##### delete

```coffeescript
user.where(id: 3).delete (err) -> # ...
```

`where` can take any valid [criterion](https://github.com/snd/criterion)

##### update

```coffeescript
user.where(id: 3).where(name: 'foo').update {name: 'bar'}, (err) -> # ...
```

multiple calls to `where` are anded together.

### query

##### find the first

```coffeescript
user.where(id: 3).first (err, user) -> # ...
```

`where` can take any valid [criterion](https://github.com/snd/criterion)

##### test for existence

```coffeescript
user.where(id: 3).exists (err, exists) -> # ...
```

##### find all

```coffeescript
user.where(id: 3).find (err, users) -> # ...
```

##### select, join, group, order, limit, offset

```coffeescript
user
    .select('user.*, count(project.id) AS project_count')
    .where(id: 3)
    .where('name = ?', 'foo')
    .join('JOIN project ON user.id = project.user_id')
    .group('user.id')
    .order('created DESC, name ASC')
    .limit(10)
    .offset(20)
    .find (err, users) ->
```

mesa uses [mohair](https://github.com/snd/mohair) for `where`, `select`, `join`, `group`, `order`, `limit` and `order`.
look [here](https://github.com/snd/mohair) for further documentation.

### associations

##### has one

use `hasOne` if the foreign key is in the other table (`user` in this example)

```coffeescript
user.hasOne 'address', address,
    primaryKey: 'id'        # optional with default: "id"
    foreignKey: 'user_id'   # optional with default: "#{user.getTable()}_id"
```

the second argument can be a function which must return a model.
this can be used to resolve models which are not yet created when the association
is defined.
its also a way to do self associations.

##### belongs to

use `belongsTo` if the foreign key is in the table of the model that `belongsTo`
is defined on (`project` in this example)

```coffeescript
project.belongsTo 'user', user,
    primaryKey: 'id'        # optional with default: "id"
    foreignKey: 'user_id'   # optional with default: "#{user.getTable()}_id"
```

###### has many

use `hasMany` if the foreign key is in the other table (`user` in this example) and
there are multiple associated records

```coffeescript
user.hasMany 'projects', project,
    primaryKey: 'id'        # optional with default: "id"
    foreignKey: 'user_id'   # optional with default: "#{user.getTable()}_id"
```

###### has and belongs to many

use `hasAndBelongsToMany` if the association uses a join table

```coffeescript
user.hasAndBelongsToMany 'projects', project,
    joinTable: 'user_project'       # required
    primaryKey: 'id'                # optional with default: "id"
    foreignKey: 'user_id'           # optional with default: "#{user.getTable()}_id"
    otherPrimaryKey: 'id'           # optional with default: "id"
    otherForeignKey: 'project_id'   # optional with default: "#{project.getTable()}_id"
```

##### including associated

associations are only fetched if you `include` them

```coffeescript
user.includes(address: true)
```

includes can be nested (arbitrarily deep)

```coffeescript
user.includes(shipping_address: {street: true, town: true}, billing_address: true, friends: {billing_address: true})
```

### todo

- better documentation
- more convincing usage examples
- check more user errors
- use underscore less
- refactor association fetching code

### license: MIT
