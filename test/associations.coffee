mesa = require '../src/postgres'

mesa.enableConnectionReuseForIncludes = true

module.exports =

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

                addressTable = mesa
                    .connection(-> test.fail())
                    .table('address')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasOne('billing_address', addressTable)

                userTable
                    .includes(billing_address: true)
                    .where(id: 3)
                    .first (err, user) ->
                        throw err if err?
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

                userTable = mesa
                    .connection(-> test.fail())
                    .table('user')

                addressTable = mesa
                    .connection(connection)
                    .table('address')
                    .belongsTo('person', userTable)

                addressTable.hookBeforeIncludes = ->
                    console.log 'before includes'

                addressTable.hookBeforeGetIncludesForFirst = ->
                    console.log 'before get includes for first'

                addressTable
                    .includes(person: true)
                    .where(id: 3)
                    .first (err, address) ->
                        throw err if err?
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

                taskTable = mesa
                    .connection(-> test.fail())
                    .table('task')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasMany('tasks', taskTable)

                userTable
                    .includes(tasks: true)
                    .where(id: 3)
                    .first (err, user) ->
                        throw err if err?
                        test.deepEqual user,
                            name: 'foo'
                            id: 3
                            tasks: [
                                {name: 'do laundry', user_id: 3}
                                {name: 'buy the iphone 5', user_id: 3}
                                {name: 'learn clojure', user_id: 3}
                            ]

                        test.done()

            'hasManyThrough': (test) ->
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

                roleTable = mesa
                    .connection(connection)
                    .table('role')

                joinTable = mesa
                    .connection(connection)
                    .table('user_role')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasManyThrough('roles', roleTable, joinTable)

                userTable
                    .includes(roles: true)
                    .where(id: 3)
                    .first (err, user) ->
                        throw err if err?
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

                addressTable = mesa
                    .connection(-> test.fail())
                    .table('address')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasOne('billing_address', addressTable)

                userTable
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

                userTable = mesa
                    .connection(-> test.fail())
                    .table('user')

                addressTable = mesa
                    .connection(connection)
                    .table('address')
                    .belongsTo('person', userTable)

                addressTable
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

                taskTable = mesa
                    .connection(-> test.fail())
                    .table('task')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasMany('tasks', taskTable)

                userTable
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

            'hasManyThrough': (test) ->
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

                roleTable = mesa
                    .connection(connection)
                    .table('role')

                joinTable = mesa
                    .connection(connection)
                    .table('user_role')

                userTable = mesa
                    .connection(connection)
                    .table('user')
                    .hasManyThrough('roles', roleTable, joinTable)

                userTable
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

            table = {}
            table.address = mesa
                .connection(connection)
                .table('address')
                .hasOne('user', (-> table.user),
                    foreignKey: 'billing_id'
                )

            table.friend = mesa
                .connection(connection)
                .table('friend')

            table.user = mesa
                .connection(connection)
                .table('user')
                .belongsTo('billing_address', (-> table.address),
                    foreignKey: 'billing_id'
                )
                .belongsTo('shipping_address', (-> table.address),
                    foreignKey: 'shipping_id'
                )
                .hasManyThrough('friends', (-> table.user), (-> table.friend),
                    foreignKey: 'user_id1'
                    otherForeignKey: 'user_id2'
                )

            # include the billing address and all the friends with their
            # shipping adresses

            table.user
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

        'hasManyThrough works if there are no associated': (test) ->
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

            roleTable = mesa
                .connection(connection)
                .table('role')

            userRoleTable = mesa
                .connection(connection)
                .table('user_role')

            userTable = mesa
                .connection(connection)
                .table('user')
                .hasManyThrough('roles', roleTable, userRoleTable)

            userTable
                .includes(roles: true)
                .find (err, users) ->
                    test.deepEqual users, [
                        {
                            name: 'foo'
                            id: 3
                            roles: []
                        }
                        {
                            name: 'bar'
                            id: 4
                            roles: []
                        }
                        {
                            name: 'baz'
                            id: 5
                            roles: []
                        }
                    ]

                    test.done()
