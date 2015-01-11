{setup, teardown, mesa} = require './src/common'

module.exports =

  'setUp': setup
  'tearDown': teardown

  'json and lateral joins': (test) ->
    # inspired by:
    # http://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/

    userTable = mesa
      .table('user')

    eventTable = mesa
      .table('event')
      .allow(['id', 'user_id', 'created_at', 'data'])

    userTable.where(name: 'laura').first()
      .then (laura) ->
        # insert a couple of events
        eventTable.insert([
          {
            user_id: laura.id
            created_at: mesa.raw('now()')
            data: JSON.stringify(type: 'view_homepage')
          }
      ])
      .then (events) ->
        innerQuery = eventTable
          .select(
            'user_id',
            {view_homepage: 1}
            {view_homepage_time: 'min(created_at)'}
          )
          .where("data->>'type' = ?", 'view_homepage')
          .group('user_id')

        joinQuery = mesa
          .from({e1: innerQuery})
          .join('LEFT JOIN LATERAL')

        lateralQuery = mesa
          .table('event')
          .select(
            enter_credit_card: 1
            enter_credit_card_time: 'created_at'
          )
          # TODO do mesa.escaped here
          .where(user_id: mesa.raw('e1.user_id'))
          .where("data->>'type' = ?", 'enter_credit_card')
          .order('created_at')
          .limit(1)

        outerQuery = mesa
          .select([
            'user_id'
            'view_homepage'
            'view_homepage_time'
            'enter_credit_card'
            'enter_credit_card_time'
          ])
          .from(joinQuery)

        console.log outerQuery.sql()
        console.log lateralQuery.sql()

        test.done()
