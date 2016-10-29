import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  loading: true,
  purchased: true,

  refreshContent() {
    this.set('loading', true);
    this.set('purchased', true);

    const postId = this.get('post.id'), tollId = this.get('tollId');
    if (!postId || !tollId) { this.set('loading', false); return; }
    ajax(`${Discourse.BaseUri}/discourse_credit/tolls/${postId}/${tollId}`).then(json => {
      if (!json.purchsed) {
        this.set('purchased', false);
        this.set('body', I18n.t('credit.required_purchase', { credit: this.get('tollCredit') }));
      } else {
        this.set('body', json.cooked);
      }
    }).finally(() => {
      this.set('loading', false);
    });
  },

  actions: {
    purchase() {
      if (!Discourse.User.current()) {
        return bootbox.alert("你还没有登录。");
      }
      return bootbox.confirm(I18n.t("credit.confirm_purchase", { credit: this.get('tollCredit') }), I18n.t("no_value"), I18n.t("yes_value"), purchase => {
        const postId = this.get('post.id'), tollId = this.get('tollId');
        if (!postId || !tollId) { return; }
        if (purchase) {
          ajax(`${Discourse.BaseUri}/discourse_credit/tolls/${postId}/${tollId}`, { method: 'POST' }).then(json => {
            if (json.success) {
              this.refreshContent();
            }
          }).catch(popupAjaxError);
        }
      });
    }
  }
});
