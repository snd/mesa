_ = require 'underscore'

mesa = require '../src/postgres'

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
            userTable = mesa

            test.throws ->
                userTable.find {id: 1}, -> test.fail()
            test.done()

        "when table wasn't called": (test) ->
            userTable = mesa
                .connection(-> test.fail)

            test.throws ->
                userTable.delete -> test.fail()
            test.done()

        "when attributes wasn't called before insert": (test) ->
            userTable = mesa
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userTable.insert {name: 'foo'}, -> test.fail()
            test.done()

        "when attributes wasn't called before update": (test) ->
            userTable = mesa
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userTable.update {name: 'foo'}, -> test.fail()
            test.done()

        "when including something that has no association": (test) ->
            test.expect 1

            connection =
                query: -> test.fail()

            userTable = mesa
                .table('user')
                .includes(billing_address: true)

            test.throws ->
                userTable.fetchIncludes connection, {id: 3, name: 'foo'}, -> test.fail()

            test.done()

    'command':

        'insert a record': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "email") VALUES ($1, $2) RETURNING id'
                    test.deepEqual params, ['foo', 'foo@example.com']
                    cb null, {rows: [{id: 3}]}

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userTable.insert {name: 'foo', email: 'foo@example.com', x: 5}, (err, id) ->
                throw err if err?
                test.equal id, 3
                test.done()

        'insert with raw': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO "user"("name", "id") VALUES ($1, LOG($2, $3)) RETURNING id'
                    test.deepEqual params, ['foo', 3, 4]
                    cb null, {rows: [{id: 3}]}

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'id'])

            userTable.insert {name: 'foo', id: userTable.raw('LOG(?, ?)', 3, 4)}, (err, id) ->
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

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userTable
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

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userTable
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

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userTable.insertMany [
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

            userTable = mesa
                .connection(connection)
                .table('user')

            userTable.where(id: 3).where(name: 'foo').delete (err) ->
                throw err if err?
                test.done()

        'update': (test) ->
            test.expect 2

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE "user" SET "name" = $1, "email" = $2 WHERE (id = $3) AND (name = $4)'
                    test.deepEqual params, ['bar', 'bar@example.com', 3, 'foo']
                    cb()

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            updates = {name: 'bar', x: 5, y: 8, email: 'bar@example.com'}

            userTable.where(id: 3).where(name: 'foo').update updates, (err) ->
                throw err if err?
                test.done()

        'update with returning': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE "user" SET "name" = $1, "email" = $2 WHERE (id = $3) AND (name = $4) RETURNING *'
                    test.deepEqual params, ['bar', 'bar@example.com', 3, 'foo']
                    cb null, {rows: [{id: 3}, {id: 4}]}

            userTable = mesa
                .connection(connection)
                .table('user')
                .returning('*')
                .attributes(['name', 'email'])

            updates = {name: 'bar', x: 5, y: 8, email: 'bar@example.com'}

            userTable.where(id: 3).where(name: 'foo').update updates, (err, results) ->
                throw err if err?
                test.deepEqual results, [{id: 3}, {id: 4}]
                test.done()

        'update with raw': (test) ->
            test.expect 2

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE "user" SET "id" = LOG($1, $2), "name" = $3 WHERE (id = LOG($4, $5)) AND (name = $6)'
                    test.deepEqual params, [7, 8, 'bar', 11, 12, 'foo']
                    cb()

            userTable = mesa
                .connection(connection)
                .table('user')
                .attributes(['id', 'name'])

            updates =
                name: 'bar'
                id: userTable.raw('LOG(?, ?)', 7, 8)
                x: 5
                y: 8
                email: 'bar@example.com'

            userTable
                .where(id: userTable.raw('LOG(?, ?)', 11, 12))
                .where(name: 'foo')
                .update updates, (err) ->
                    throw err if err?
                    test.done()

    'query':

        'find all': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT name FROM "user" WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userTable = mesa
                .connection(connection)
                .table('user')

            userTable.where(id: 3).select('name').find (err, users) ->
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

            userTable = mesa
                .connection(connection)
                .table('user')

            userTable.where(id: 3).select('name').first (err, user) ->
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

            userTable = mesa
                .connection(connection)
                .table('user')

            userTable.where(id: 3).exists (err, exists) ->
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

            userTable = mesa
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

        userTable = Object.create mesa

        userTable.insert = (data, cb) ->
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

        userTable
            .table('user')
            .connection(getConnection)
            .attributes(['name', 'email'])
            .insert {name: 'foo', email: 'foo@example.com'}, (err, userId) ->
                throw err if err?
                test.equal userId, 500
                test.done()
