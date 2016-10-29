export default Em.View.extend({
  templateName: "credit-toll",
  classNames: ["credit-toll"],
  attributeBindings: ["data-credit-toll-id", "data-credit-toll-credit"],

  creditToll: Em.computed.alias("controller.creditToll"),

  "data-credit-toll-id": Em.computed.alias("creditToll.id"),
  "data-credit-toll-credit": Em.computed.alias("creditToll.credit"),
});
