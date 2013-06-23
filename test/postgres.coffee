mesa = require '../src/postgres'

module.exports =

    'mesa controlled connection':

        'done is called on insert': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb null, {rows: [{id: 3}]}
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')
                .attributes(['name'])

            userModel.insert {name: 'foo'}, (err, id) ->
                throw err if err?
                test.done()

        'done is called on update': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb()
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')
                .attributes(['name'])

            userModel.update {name: 'foo'}, (err) ->
                throw err if err?
                test.done()

        'done is called on delete': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb()
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')

            userModel.delete (err) ->
                throw err if err?
                test.done()

        'done is called on first when a record is returned': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb null, {rows: [{x: 1}]}
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')

            userModel.first (err) ->
                throw err if err?
                test.done()

        'done is called on first when no record is returned': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb null, {rows: []}
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')

            userModel.first (err) ->
                throw err if err?
                test.done()

        'done is called on find when a record is returned': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb null, {rows: [{x: 1}]}
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')

            userModel.find (err) ->
                throw err if err?
                test.done()

        'done is called on find when no records are returned': (test) ->
            test.expect 1

            getConnection = (cb) ->
                process.nextTick ->
                    done = -> test.ok true
                    connection =
                        query: (sql, params, cb) ->
                            cb null, {rows: []}
                    cb null, connection, done

            userModel = mesa
                .connection(getConnection)
                .table('user')

            userModel.find (err) ->
                throw err if err?
                test.done()
