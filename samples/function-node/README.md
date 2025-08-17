# Sample Azure Function (Node 18) - HTTP trigger to enqueue to Service Bus

This is a minimal sample showing how your Function can use **Managed Identity**
to send to the private Service Bus. It expects the app setting `SERVICEBUS_NAMESPACE`.
