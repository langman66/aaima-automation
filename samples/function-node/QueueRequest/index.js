
const { DefaultAzureCredential } = require("@azure/identity");
const { ServiceBusClient } = require("@azure/service-bus");
module.exports = async function (context, req) {
  try {
    const ns = process.env.SERVICEBUS_NAMESPACE;
    const credential = new DefaultAzureCredential();
    const sbClient = new ServiceBusClient(`https://${ns}/`, credential);
    const sender = sbClient.createSender(`q-aaima-requests`);
    const body = req.body || { time: new Date().toISOString(), msg: "hello" };
    await sender.sendMessages({ body, contentType: "application/json" });
    await sender.close(); await sbClient.close();
    context.res = { status: 202, body: { enqueued: true } };
  } catch (err) {
    context.log.error(err);
    context.res = { status: 500, body: { error: err.message } };
  }
}
