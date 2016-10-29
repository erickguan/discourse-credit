import { registerOption } from 'pretty-text/pretty-text';

const DATA_PREFIX = "data-credit-toll-";
const WHITELISTED_ATTRIBUTES = ["id", "credit"];
const ATTRIBUTES_REGEX = new RegExp("(" + WHITELISTED_ATTRIBUTES.join("|") + ")=['\"]?[^\\s\\]]+['\"]?", "g");

registerOption((siteSettings, opts) => {
  const currentUser = (opts.getCurrentUser && opts.getCurrentUser(opts.userId)) || opts.currentUser;

  opts.features["credit-toll"] = !!siteSettings.credit_enabled;
});

export function setup(helper) {
  helper.whiteList(['div.credit-toll']);

  helper.replaceBlock({
    start: /\[credit-toll((?:\s+\w+=[^\s\]]+)*)\]([\s\S]*)/igm,
    stop: /\[\/credit-toll\]/igm,

    emitter(blockContents, matches) {
      const contents = [];

      // post-process inside block contents
      if (blockContents.length) {
        const postProcess = bc => {
          contents.push(["p"]);
        };

        let b;
        while ((b = blockContents.shift()) !== undefined) {
          this.processBlock(b, blockContents).forEach(postProcess);
        }
      }

      // extract credit toll attributes
      const attributes = { "class": "credit-toll" };
      (matches[1].match(ATTRIBUTES_REGEX) || []).forEach(function(m) {
        const [ name, value ] = m.split("=");
        const escaped = helper.escape(value.replace(/["']/g, ""));
        attributes[DATA_PREFIX + name] = escaped;
      });

      const result = ["div", attributes];

      return result;
    }
  });
}

