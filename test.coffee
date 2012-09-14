_ = require 'underscore'

Model = require './index'

module.exports =

    'throw':

        "when connection wasn't called": (test) ->
            userModel = new Model()

            test.throws ->
                userModel.find {id: 1}, -> test.fail()
            test.done()

        "when table wasn't called": (test) ->
            userModel = new Model()
                .connection(-> test.fail)

            test.throws ->
                userModel.find {id: 1}, -> test.fail()
            test.done()

        "when attributes wasn't called before insert": (test) ->
            userModel = new Model()
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userModel.insert {name: 'foo'}, -> test.fail()
            test.done()

        "when attributes wasn't called before update": (test) ->
            userModel = new Model()
                .connection(-> test.fail)
                .table('user')

            test.throws ->
                userModel.update {name: 'foo'}, -> test.fail()
            test.done()

    'command':

        'insert a record': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO user(name, email) VALUES ($1, $2) RETURNING id'
                    test.deepEqual params, ['foo', 'foo@example.com']
                    cb null, {rows: [{id: 3}]}

            userModel = new Model()
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel.insert {name: 'foo', email: 'foo@example.com', x: 5}, (err, id) ->
                throw err if err?
                test.equal id, 3
                test.done()

        'insert multiple records': (test) ->

            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'INSERT INTO user(name, email) VALUES ($1, $2), ($3, $4) RETURNING id'
                    test.deepEqual params, ['foo', 'foo@example.com', 'bar', 'bar@example.com']
                    cb null, {rows: [{id: 3}, {id: 4}]}

            userModel = new Model()
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            userModel.insert [
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
                    test.equal sql, 'DELETE FROM user WHERE id = $1 AND name = $2'
                    test.deepEqual params, [3, 'foo']
                    cb()

            userModel = new Model()
                .connection(connection)
                .table('user')

            userModel.where(id: 3).where(name: 'foo').delete (err) ->
                throw err if err?
                test.done()

        'update': (test) ->
            test.expect 2

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'UPDATE user SET name = $1, email = $2 WHERE id = $3 AND name = $4'
                    test.deepEqual params, ['bar', 'bar@example.com', 3, 'foo']
                    cb()

            userModel = new Model()
                .connection(connection)
                .table('user')
                .attributes(['name', 'email'])

            updates = {name: 'bar', x: 5, y: 8, email: 'bar@example.com'}

            userModel.where(id: 3).where(name: 'foo').update updates, (err) ->
                throw err if err?
                test.done()

    'query':

        'find all': (test) ->
            test.expect 3

            connection =
                query: (sql, params, cb) ->
                    test.equal sql, 'SELECT name FROM user WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = new Model()
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
                    test.equal sql, 'SELECT name FROM user WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = new Model()
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
                    test.equal sql, 'SELECT * FROM user WHERE id = $1'
                    test.deepEqual params, [3]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = new Model()
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
                    test.equal sql, 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id WHERE id = $1 AND name = $2 GROUP BY user.id ORDER BY created DESC, name ASC LIMIT $3 OFFSET $4'
                    test.deepEqual params, [3, 'foo', 10, 20]
                    cb null, {rows: [{name: 'foo'}, {name: 'bar'}]}

            userModel = new Model()
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

    # shadowing:

    # immutability:

    # extending:
