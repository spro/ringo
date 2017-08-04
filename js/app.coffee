React = require 'react'
ReactDOM = require 'react-dom'
Redux = require 'redux'
Kefir = require 'kefir'
somata = require 'somata-socketio-client'

# Store
# ------------------------------------------------------------------------------

initial_state = {
    loading: true
}

reducer = (state={}, action) ->
    switch action.type
        when 'setBoard'
            {board, alerts} = action
            return Object.assign {}, state, {loading: false, board, alerts}
    return state

Store = Redux.createStore reducer, initial_state

# Dispatcher
# ------------------------------------------------------------------------------

user_id = window.location.hash.slice(1)
if !user_id?.length
    user_id = prompt "Set your username"
    window.location.hash = user_id

Dispatcher =
    getBoard: ->
        somata.remote$ 'bingo', 'getBoard', user_id

    claimSquare: (square_id) ->
        somata.remote$ 'bingo', 'claimSquare', square_id, user_id
            .log 'claimed'

    voteSquare: (square_id, vote) ->
        somata.remote$ 'bingo', 'voteSquare', square_id, user_id, vote
            .log 'voted'

Dispatcher.getBoard user_id
    .onValue ({board, alerts}) ->
        Store.dispatch {type: 'setBoard', board, alerts}

somata.connect ->
    console.log '[connected]'

somata.subscribe$ 'bingo', 'updateBoard:' + user_id
    .onValue ({board, alerts}) ->
        Store.dispatch {type: 'setBoard', board, alerts}

# Components
# ------------------------------------------------------------------------------

class App extends React.Component
    constructor: ->
        @state = Store.getState()
        Store.subscribe =>
            @setState Store.getState()

    render: ->
        {loading, board, alerts} = @state

        <div id='container'>
            <div id='header'>
                <img src='/images/logo.png' />
                <div id='navigation'>
                    <a className='selected'>Board</a>
                    <a className='unselected'>Leaderboard</a>
                </div>
                <span className='username'>{user_id}</span>
            </div>

            {if loading
                <p>Loading...</p>
            else
                [0...5].map (row) ->
                    <div className='row' key=row>
                        {[0...5].map (col) ->
                            square = board[row][col]
                            square_class = "square"
                            if square.pending
                                square_class += ' pending'
                            if square.confirmed
                                square_class += ' confirmed'
                            <div className=square_class key=col onClick={Dispatcher.claimSquare.bind(null, square.id)}>
                                <span>{square.text}</span>
                            </div>
                        }
                    </div>
            }

            {if alerts?.length
                <div className='alerts'>
                    {alerts.map (alert) ->
                        <div className='alert' key=alert.square.id>
                            <p className='message'>{alert.user_id} claims <strong>{alert.square.text}</strong></p>
                            <div className='buttons'>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, 1)}>Confirm</a>
                                <a onClick={Dispatcher.voteSquare.bind(null, alert.square.id, -1)}>Deny</a>
                            </div>
                        </div>
                    }
                </div>
            }
        </div>

ReactDOM.render <App />, document.getElementById 'app'
