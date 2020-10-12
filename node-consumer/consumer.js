const amqplib = require('amqplib')

const HOST = process.env.RABBIT_HOST
const PORT = process.env.RABBIT_PORT
const USERNAME = process.env.RABBIT_USERNAME
const PASSWORD = process.env.RABBIT_PASSWORD;

(async function() {
    const open = await amqplib.connect(`amqp://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/`)
    const channel = await open.createChannel()
    await channel.assertQueue('publisher')

    channel.consume('publisher', (msg) => {
        if (msg !== null) {
            console.log(msg.content.toString())
            channel.ack(msg)
        }
    })
}())
