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

`connection` either takes a function (see above) or a connection object.
giving a connection object explictely is useful when you use transactions.
at the moment model only works with the pg module.

`attributes` has to be in the chain if you wan't to use `create` or `update`

### command

##### insert a record

```coffeescript
user.insert {
    name: 'foo'
}, (err, userId) -> # ...
```

# insert multiple records

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

multiple calls to `where` are anded together.

##### update

```coffeescript
user.where(id: 3).update {name: 'bar'}, (err) -> # ...
```

### query

##### find all

```coffeescript
user.where(id: 3).find (err, users) -> # ...
```

##### find the first

```coffeescript
user.where(id: 3).first (err, user) -> # ...
```

##### test for existence

```coffeescript
user.where(id: 3).exists (err, exists) -> # ...
```

for all the possible things see mohair

### license: MIT
