_ = require 'underscore'

mesa = require './index'

module.exports =

    'set and get': (test) ->
        m = mesa
        m1 = m.set('string', 'foo')
        m2 = m1.set('number', 1)
        m3 = m2.set('string', 'bar')
        m4 = m3.set('number', 2)
        m5 = m4.set('string', 'baz')
        m6 = m5.set('number', 3)

        test.ok not m.string?
        test.ok not m.number?

        test.equal 'foo', m1.string
        test.ok not m1.number?

        test.equal 'foo', m2.string
        test.equal 1, m2.number

        test.equal 'bar', m3.string
        test.equal 1, m3.number

        test.equal 'bar', m4.string
        test.equal 2, m4.number

        test.equal 'baz', m5.string
        test.equal 2, m5.number

        test.equal 'baz', m6.string
        test.equal 3, m6.number

        test.done()

    'throw':

        "when connection wasn't called": (test) ->
            userModel = mesa

            test.throws ->
                userModel.find {id: 1}, -> test.fail()
            test.done()

        "when table wasn't called": (test) ->
            userModel = mesa
                .connection(-> test.fail)

            test.throws ->
                userModel.find {id: 1}, -> test.fail()
            test.done()

        "when attributes wasn't called before insert": (test) ->
            userModel = mesa
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userModel.insert {name: 'foo'}, -> test.fail()
            test.done()

        "when attributes wasn't called before update": (test) ->
            userModel = mesa
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userModel.update {name: 'foo'}, -> test.fail()
            test.done()

        "when including something that has no association": (test) ->
            test.expect 1

            connection =
                query: -> test.fail()

            userModel = mesa
                .table('user')
                .includes(billing_address: true)

            test.throws ->
                userModel.fetchIncludes connection, {id: 3, name: 'foo'}, -> test.fail()

            test.done()

    'command':

        'insert a record': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2) RETURNING id'
                    test.deepEqual params, ['foo', 'foo@example.com']
                    cb null, {rows: [{id: 3}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel.insert {name: 'foo', email: 'foo@example.com', x: 5}, (err, id) ->
                throw err if err?
                test.equal id, 3
                test.done()

        'insert with custom primaryKey': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2) RETURNING my_id'
                    test.deepEqual params, ['foo', 'foo@example.com']
                    cb null, {rows: [{id: 3, my_id: 5}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel
                .primaryKey('my_id')
                .insert {name: 'foo', email: 'foo@example.com', x: 5}, (err, id) ->
                    throw err if err?
                    test.equal id, 5
                    test.done()

        'insert with returning': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2) RETURNING *'
                    test.deepEqual params, ['foo', 'foo@example.com']
                    cb null, {rows: [{id: 3, name: 'foo', email: 'foo@example.com'}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel
                .primaryKey('my_id')
                .returning('*')
                .insert {name: 'foo', email: 'foo@example.com', x: 5}, (err, record) ->
                    throw err if err?
                    test.deepEqual record,
                        id: 3
                        name: 'foo'
                        email: 'foo@example.com'

                    test.done()

        'insert multiple records': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2), ($3, $4) RETURNING id'
                    test.deepEqual params, ['foo', 'foo@example.com', 'bar', 'bar@example.com']
                    cb null, {rows: [{id: 3}, {id: 4}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel.insertMany [
                {name: 'foo', email: 'foo@example.com', x: 5}
                {name: 'bar', email: 'bar@example.com', x: 6}
            ], (err, ids) ->
                throw err if err?
                test.deepEqual ids, [3, 4]
                test.done()

        'delete': (test) ->
            test.expect 2

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'DELETE FROM "user" WHERE (id = $1) AND (name = $2)'
                    test.deepEqual params, [3, 'foo']
                    cb()

            userModel = mesa
                .connection(connection)
                .table('user')

            userModel.where(id: 3).where(name: 'foo').delete (err) ->
                throw err if err?
                test.done()

        'update': (test) ->
            test.expect 2

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE "user" SET "name" = $1, "email" = $2 WHERE (id = $3) AND (name = $4)'
                    test.deepEqual params, ['bar', 'bar@example.com', 3, 'foo']
                    cb()

            userModel = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            updates = {name: 'bar', x: 5, y: 8, email: 'bar@example.com'}

            userModel.where(id: 3).where(name: 'foo').update updates, (err) ->
                throw err if err?
                test.done()

        'update with returning': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE "user" SET "name" = $1, "email" = $2 WHERE (id = $3) AND (name = $4) RETURNING *'
                    test.deepEqual params, ['bar', 'bar@example.com', 3, 'foo']
                    cb null, {rows: [{id: 3}, {id: 4}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .returning('*')
                .attributes(['name', 'email'])

            updates = {name: 'bar', x: 5, y: 8, email: 'bar@example.com'}

            userModel.where(id: 3).where(name: 'foo').update updates, (err, results) ->
                throw err if err?
                test.deepEqual results, [{id: 3}, {id: 4}]
                test.done()

    'query':

        'find all': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT name FROM "user" WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = mesa
                .connection(connection)
                .table('user')

            userModel.where(id: 3).select('name').find (err, users) ->
                throw err if err?
                test.deepEqual users, [{name: 'foo'}, {name: 'bar'}]
                test.done()

        'find the first': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT name FROM "user" WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = mesa
                .connection(connection)
                .table('user')

            userModel.where(id: 3).select('name').first (err, user) ->
                throw err if err?
                test.deepEqual user, {name: 'foo'}
                test.done()

        'test for existence': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT * FROM "user" WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = mesa
                .connection(connection)
                .table('user')

            userModel.where(id: 3).exists (err, exists) ->
                throw err if err?
                test.ok exists
                test.done()

        'everything together': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT user.*, count(project.id) AS project_count FROM "user" JOIN project ON user.id = project.user_id WHERE (id = $1) AND (name = $2) GROUP BY user.id ORDER BY created DESC, name ASC LIMIT $3 OFFSET $4'
                    test.deepEqual params, [3, 'foo', 10, 20]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = mesa
                .connection(connection)
                .table('user')
                .select('user.*, count(project.id) AS project_count')
                .where(id: 3)
                .where('name = ?', 'foo')
                .join('JOIN project ON user.id = project.user_id')
                .group('user.id')
                .order('created DESC, name ASC')
                .limit(10)
                .offset(20)
                .find (err, users) ->
                    throw err if err?
                    test.deepEqual users, [{name: 'foo'}, {name: 'bar'}]
                    test.done()

    'extending': (test) ->

        test.expect 8

        userModel = Object.create mesa

        userModel.insert = (data, cb) ->
            @getConnection (err, connection) =>
                return cb err if err?

                connection.query 'BEGIN;', [], (err) =>
                    return cb err if err?

                    # do the original insert, but on the connection we just got
                    # and started the transaction on
                    mesa.insert.call @connection(connection), data, (err, userId) =>
                        return cb err if err?

                        test.equal userId, 200

                        # do other things in the transaction...

                        connection.query 'COMMIT;', [], (err) =>
                            return cb err if err?
                            cb null, 500

        getConnection = (cb) ->
            call = 1

            cb null,
                query: (sql, params, cb) ->

                    switch call++
                        when 1
                            test.equal sql, 'BEGIN;'
                            test.deepEqual params, []
                            cb()
                        when 2
                            test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2) RETURNING id'
                            test.deepEqual params, ['foo', 'foo@example.com']
                            cb null, {rows: [{id: 200}]}
                        when 3
                            test.equal sql, 'COMMIT;'
                            test.deepEqual params, []
                            cb()

        userModel
            .table('user')
            .connection(getConnection)
            .attributes(['name', 'email'])
            .insert {name: 'foo', email: 'foo@example.com'}, (err, userId) ->
                throw err if err?
                test.equal userId, 500
                test.done()

    'associations':

        'first':

            'hasOne': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user" WHERE id = $1'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 4}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "address" WHERE user_id IN ($1)'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {street: 'foo street', zip_code: 12345, user_id: 3}
                                    {street: 'djfslkfj', zip_code: 12345, user_id: 4}
                                ]}

                addressModel = mesa
                    .connection(-> test.fail())
                    .table('address')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasOne('billing_address', addressModel)

                userModel
                    .includes(billing_address: true)
                    .where(id: 3)
                    .first (err, user) ->
                        test.deepEqual user,
                            name: 'foo'
                            id: 3
                            billing_address:
                                street: 'foo street'
                                zip_code: 12345
                                user_id: 3

                        test.done()

            'belongsTo': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "address" WHERE id = $1'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {street: 'foo street', zip_code: 12345, user_id: 3}
                                    {street: 'bar street', zip_code: 12345, user_id: 10}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "user" WHERE id IN ($1)'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 10}
                                    {name: 'baz', id: 4}
                                ]}

                userModel = mesa
                    .connection(-> test.fail())
                    .table('user')

                addressModel = mesa
                    .connection(connection)
                    .table('address')
                    .belongsTo('person', userModel)

                addressModel
                    .includes(person: true)
                    .where(id: 3)
                    .first (err, address) ->
                        test.deepEqual address,
                            street: 'foo street'
                            zip_code: 12345
                            user_id: 3
                            person:
                                name: 'foo'
                                id: 3

                        test.done()

            'hasMany': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user" WHERE id = $1'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 4}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "task" WHERE user_id IN ($1)'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {name: 'do laundry', user_id: 3}
                                    {name: 'buy groceries', user_id: 4}
                                    {name: 'buy the iphone 5', user_id: 3}
                                    {name: 'learn clojure', user_id: 3}
                                ]}

                taskModel = mesa
                    .connection(-> test.fail())
                    .table('task')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasMany('tasks', taskModel)

                userModel
                    .includes(tasks: true)
                    .where(id: 3)
                    .first (err, user) ->
                        test.deepEqual user,
                            name: 'foo'
                            id: 3
                            tasks: [
                                {name: 'do laundry', user_id: 3}
                                {name: 'buy the iphone 5', user_id: 3}
                                {name: 'learn clojure', user_id: 3}
                            ]

                        test.done()

            'hasAndBelongsToMany': (test) ->
                test.expect 7

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user" WHERE id = $1'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 4}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "user_role" WHERE user_id IN ($1)'
                                test.deepEqual params, [3]
                                cb null, {rows: [
                                    {user_id: 3, role_id: 30}
                                    {user_id: 3, role_id: 40}
                                    {user_id: 3, role_id: 60}
                                ]}
                            when 3
                                test.equal sql, 'SELECT * FROM "role" WHERE id IN ($1, $2, $3)'
                                test.deepEqual params, [30, 40, 60]
                                cb null, {rows: [
                                    {id: 30, name: 'jedi'}
                                    {id: 40, name: 'administrator'}
                                    {id: 60, name: 'master of the universe'}
                                    {id: 50, name: 'bad bad role'}
                                ]}

                roleModel = mesa
                    .connection(connection)
                    .table('role')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasAndBelongsToMany('roles', roleModel,
                        joinTable: 'user_role'
                    )

                userModel
                    .includes(roles: true)
                    .where(id: 3)
                    .first (err, user) ->
                        test.deepEqual user,
                            name: 'foo'
                            id: 3
                            roles: [
                                {id: 30, name: 'jedi'}
                                {id: 40, name: 'administrator'}
                                {id: 60, name: 'master of the universe'}
                            ]

                        test.done()

        'find':

            'hasOne': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user"'
                                test.deepEqual params, []
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 10}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "address" WHERE user_id IN ($1, $2)'
                                test.deepEqual params, [3, 10]
                                cb null, {rows: [
                                    {street: 'foo street', zip_code: 12345, user_id: 3}
                                    {street: 'djfslkfj', zip_code: 12345, user_id: 4}
                                    {street: 'bar street', zip_code: 12345, user_id: 10}
                                ]}

                addressModel = mesa
                    .connection(-> test.fail())
                    .table('address')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasOne('billing_address', addressModel)

                userModel
                    .includes(billing_address: true)
                    .find (err, users) ->
                        test.deepEqual users, [
                            {
                                name: 'foo'
                                id: 3
                                billing_address:
                                    street: 'foo street'
                                    zip_code: 12345
                                    user_id: 3
                            }
                            {
                                name: 'bar'
                                id: 10
                                billing_address:
                                    street: 'bar street'
                                    zip_code: 12345
                                    user_id: 10
                            }
                        ]

                        test.done()

            'belongsTo': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "address"'
                                test.deepEqual params, []
                                cb null, {rows: [
                                    {street: 'foo street', zip_code: 12345, user_id: 3}
                                    {street: 'bar street', zip_code: 12345, user_id: 10}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "user" WHERE id IN ($1, $2)'
                                test.deepEqual params, [3, 10]
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 10}
                                    {name: 'baz', id: 4}
                                ]}

                userModel = mesa
                    .connection(-> test.fail())
                    .table('user')

                addressModel = mesa
                    .connection(connection)
                    .table('address')
                    .belongsTo('person', userModel)

                addressModel
                    .includes(person: true)
                    .find (err, addresses) ->
                        test.deepEqual addresses, [
                            {
                                street: 'foo street'
                                zip_code: 12345
                                user_id: 3
                                person:
                                    name: 'foo'
                                    id: 3
                            }
                            {
                                street: 'bar street'
                                zip_code: 12345
                                user_id: 10
                                person:
                                    name: 'bar'
                                    id: 10
                            }
                        ]

                        test.done()

            'hasMany': (test) ->
                test.expect 5

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user"'
                                test.deepEqual params, []
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 4}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "task" WHERE user_id IN ($1, $2)'
                                test.deepEqual params, [3, 4]
                                cb null, {rows: [
                                    {name: 'do laundry', user_id: 3}
                                    {name: 'buy groceries', user_id: 4}
                                    {name: 'foo', user_id: 3}
                                    {name: 'bar', user_id: 3}
                                    {name: 'buy the iphone 5', user_id: 5}
                                    {name: 'learn clojure', user_id: 4}
                                ]}

                taskModel = mesa
                    .connection(-> test.fail())
                    .table('task')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasMany('tasks', taskModel)

                userModel
                    .includes(tasks: true)
                    .find (err, users) ->
                        test.deepEqual users, [
                            {
                                name: 'foo'
                                id: 3
                                tasks: [
                                    {name: 'do laundry', user_id: 3}
                                    {name: 'foo', user_id: 3}
                                    {name: 'bar', user_id: 3}
                                ]
                            }
                            {
                                name: 'bar'
                                id: 4
                                tasks: [
                                    {name: 'buy groceries', user_id: 4}
                                    {name: 'learn clojure', user_id: 4}
                                ]
                            }
                        ]

                        test.done()

            'hasAndBelongsToMany': (test) ->
                test.expect 7

                call = 1

                connection =
                    query: (sql, params, cb) ->
                        switch call++
                            when 1
                                test.equal sql, 'SELECT * FROM "user"'
                                test.deepEqual params, []
                                cb null, {rows: [
                                    {name: 'foo', id: 3}
                                    {name: 'bar', id: 4}
                                    {name: 'baz', id: 5}
                                ]}
                            when 2
                                test.equal sql, 'SELECT * FROM "user_role" WHERE user_id IN ($1, $2, $3)'
                                test.deepEqual params, [3, 4, 5]
                                cb null, {rows: [
                                    {user_id: 5, role_id: 40}
                                    {user_id: 5, role_id: 60}
                                    {user_id: 3, role_id: 30}
                                    {user_id: 4, role_id: 60}
                                    {user_id: 3, role_id: 40}
                                    {user_id: 3, role_id: 60}
                                    {user_id: 5, role_id: 50}
                                ]}
                            when 3
                                test.equal sql, 'SELECT * FROM "role" WHERE id IN ($1, $2, $3, $4)'
                                test.deepEqual params, [40, 60, 30, 50]
                                cb null, {rows: [
                                    {id: 30, name: 'jedi'}
                                    {id: 40, name: 'administrator'}
                                    {id: 60, name: 'master of the universe'}
                                    {id: 50, name: 'bad bad role'}
                                ]}

                roleModel = mesa
                    .connection(connection)
                    .table('role')

                userModel = mesa
                    .connection(connection)
                    .table('user')
                    .hasAndBelongsToMany('roles', roleModel,
                        joinTable: 'user_role'
                    )

                userModel
                    .includes(roles: true)
                    .find (err, users) ->
                        test.deepEqual users, [
                            {
                                name: 'foo'
                                id: 3
                                roles: [
                                    {id: 30, name: 'jedi'}
                                    {id: 40, name: 'administrator'}
                                    {id: 60, name: 'master of the universe'}
                                ]
                            }
                            {
                                name: 'bar'
                                id: 4
                                roles: [
                                    {id: 60, name: 'master of the universe'}
                                ]
                            }
                            {
                                name: 'baz'
                                id: 5
                                roles: [
                                    {id: 40, name: 'administrator'}
                                    {id: 60, name: 'master of the universe'}
                                    {id: 50, name: 'bad bad role'}
                                ]
                            }
                        ]

                        test.done()

        'self associations with custom keys and nested includes': (test) ->
            test.expect 15

            call = 1

            connection =
                query: (sql, params, cb) ->
                    switch call++
                        when 1
                            test.equal sql, 'SELECT * FROM "user"'
                            test.deepEqual params, []
                            cb null, {rows: [
                                {name: 'foo', id: 1, shipping_id: 11, billing_id: 101}
                                {name: 'bar', id: 2, shipping_id: 12, billing_id: 102}
                                {name: 'baz', id: 3, shipping_id: 13, billing_id: 103}
                            ]}
                        when 2
                            test.equal sql, 'SELECT * FROM "friend" WHERE user_id1 IN ($1, $2, $3)'
                            test.deepEqual params, [1, 2, 3]
                            cb null, {rows: [
                                {user_id1: 1, user_id2: 2}
                                {user_id1: 2, user_id2: 3}
                                {user_id1: 3, user_id2: 1}
                                {user_id1: 3, user_id2: 2}
                            ]}
                        when 3
                            test.equal sql, 'SELECT * FROM "user" WHERE id IN ($1, $2, $3)'
                            test.deepEqual params, [2, 3, 1]
                            cb null, {rows: [
                                {name: 'bar', id: 2, shipping_id: 12, billing_id: 102}
                                {name: 'baz', id: 3, shipping_id: 13, billing_id: 103}
                                {name: 'foo', id: 1, shipping_id: 11, billing_id: 101}
                            ]}
                        when 4
                            test.equal sql, 'SELECT * FROM "address" WHERE id IN ($1, $2, $3)'
                            test.deepEqual params, [12, 13, 11]
                            cb null, {rows: [
                                {street: 'bar shipping street', id: 12}
                                {street: 'baz shipping street', id: 13}
                                {street: 'foo shipping street', id: 11}
                            ]}
                        when 5
                            test.equal sql, 'SELECT * FROM "address" WHERE id IN ($1, $2, $3)'
                            test.deepEqual params, [101, 102, 103]
                            cb null, {rows: [
                                {street: 'foo billing street', id: 101}
                                {street: 'bar billing street', id: 102}
                                {street: 'baz billing street', id: 103}
                            ]}
                        when 6
                            test.equal sql, 'SELECT * FROM "user" WHERE billing_id IN ($1, $2, $3)'
                            test.deepEqual params, [101, 102, 103]
                            cb null, {rows: [
                                {name: 'bar', id: 2, shipping_id: 12, billing_id: 102}
                                {name: 'foo', id: 1, shipping_id: 11, billing_id: 101}
                                {name: 'baz', id: 3, shipping_id: 13, billing_id: 103}
                            ]}

            model = {}
            model.address = mesa
                .connection(connection)
                .table('address')
                .hasOne('user', (-> model.user),
                    foreignKey: 'billing_id'
                )

            model.user = mesa
                .connection(connection)
                .table('user')
                .belongsTo('billing_address', (-> model.address),
                    foreignKey: 'billing_id'
                )
                .belongsTo('shipping_address', (-> model.address),
                    foreignKey: 'shipping_id'
                )
                .hasAndBelongsToMany('friends', (-> model.user),
                    joinTable: 'friend'
                    foreignKey: 'user_id1'
                    otherForeignKey: 'user_id2'
                )

            # include the billing address and all the friends with their
            # shipping adresses

            model.user
                .includes(
                    friends: {shipping_address: true}
                    billing_address: {user: true}
                )
                .find (err, users) ->

                    test.deepEqual users[0],
                        name: 'foo'
                        id: 1
                        shipping_id: 11
                        billing_id: 101
                        friends: [
                            {
                                name: 'bar'
                                id: 2
                                shipping_id: 12
                                billing_id: 102
                                shipping_address: {
                                    street: 'bar shipping street'
                                    id: 12
                                }
                            }
                        ]
                        billing_address: {
                            street: 'foo billing street'
                            id: 101
                            user: {
                                name: 'foo'
                                id: 1
                                shipping_id: 11
                                billing_id: 101
                            }
                        }

                    test.deepEqual users[1],
                        name: 'bar'
                        id: 2
                        shipping_id: 12
                        billing_id: 102
                        friends: [
                            {
                                name: 'baz'
                                id: 3
                                shipping_id: 13
                                billing_id: 103
                                shipping_address: {
                                    street: 'baz shipping street'
                                    id: 13
                                }
                            }
                        ]
                        billing_address: {
                            street: 'bar billing street'
                            id: 102
                            user: {
                                name: 'bar'
                                id: 2
                                shipping_id: 12
                                billing_id: 102
                            }
                        }

                    test.deepEqual users[2],
                        name: 'baz'
                        id: 3
                        shipping_id: 13
                        billing_id: 103
                        friends: [
                            {
                                name: 'bar'
                                id: 2
                                shipping_id: 12
                                billing_id: 102
                                shipping_address: {
                                    street: 'bar shipping street'
                                    id: 12
                                }
                            }
                            {
                                name: 'foo'
                                id: 1
                                shipping_id: 11
                                billing_id: 101
                                shipping_address: {
                                    street: 'foo shipping street'
                                    id: 11
                                }
                            }
                        ]
                        billing_address: {
                            street: 'baz billing street'
                            id: 103
                            user: {
                                name: 'baz'
                                id: 3
                                shipping_id: 13
                                billing_id: 103
                            }
                        }

                    test.done()

        'hasAndBelongsToMany works if there are no associated': (test) ->
            test.expect 5

            call = 1

            connection =
                query: (sql, params, cb) ->
                    switch call++
                        when 1
                            test.equal sql, 'SELECT * FROM "user"'
                            test.deepEqual params, []
                            cb null, {rows: [
                                {name: 'foo', id: 3}
                                {name: 'bar', id: 4}
                                {name: 'baz', id: 5}
                            ]}
                        when 2
                            test.equal sql, 'SELECT * FROM "user_role" WHERE user_id IN ($1, $2, $3)'
                            test.deepEqual params, [3, 4, 5]
                            cb null, {rows: []}

            roleModel = mesa
                .connection(connection)
                .table('role')

            userModel = mesa
                .connection(connection)
                .table('user')
                .hasAndBelongsToMany('roles', roleModel,
                    joinTable: 'user_role'
                )

            userModel
                .includes(roles: true)
                .find (err, users) ->
                    test.deepEqual users, [
                        {
                            name: 'foo'
                            id: 3
                        }
                        {
                            name: 'bar'
                            id: 4
                        }
                        {
                            name: 'baz'
                            id: 5
                        }
                    ]

                    test.done()
