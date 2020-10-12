const express = require('express')
const amqplib = require('amqplib')

const app = express()

const HOST = process.env.RABBIT_HOST
const PORT = process.env.RABBIT_PORT
const USERNAME = process.env.RABBIT_USERNAME
const PASSWORD = process.env.RABBIT_PASSWORD;

const open = amqplib.connect(`amqp://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/`)

let channel

open
.then(conn => conn.createChannel())
.then(ch => { 
    channel = ch
    ch.assertQueue('publisher') 
})


// curl -X POST http://localhost:3000/publish/hello
app.post('/publish/:message', (req, res) => {
    console.log(`message: ${req.params.message}`)

    channel.sendToQueue('publisher', Buffer.from(req.params.message))

    res.send('')
})

app.listen(3000, () => { 
    console.log('Listening on port 3000') 
})
