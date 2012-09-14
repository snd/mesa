# schemen

is not an orm

### install

```
npm install schemen
```

### configure

```coffeescript
pg = require 'pg'
Model = require 'model'

getConnection = (cb) -> pg.create 'tcp://foo@localhost/bar', cb

user = new Model()
    .table('user')
    .connection(getConnection)
    .attributes(['name', 'email'])
```

`connection` either takes a connection object or a function, which is supposed to take a
callback and call it with a connection object.
providing a connection object explictely is useful when you use transactions.
at the moment model only works with the pg module.

`attributes` sets the keys to pick from data in `create` and `update`
you have to call it before you use `create` or `update`

### command

##### insert a record

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

for more documentation on `select`, `join`, ... see [mohair](https://github.com/snd/mohair)

everything chains!

### license: MIT
