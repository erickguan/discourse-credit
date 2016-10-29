import { ajax } from 'discourse/lib/ajax';
import computed from "ember-addons/ember-computed-decorators";
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import InputValidation from 'discourse/models/input-validation';

export default Ember.Controller.extend(ModalFunctionality, {
  credit: 1,
  minCreditPermit: Ember.computed.alias('siteSettings.credit_min_permit'),
  maxCreditPermit: Ember.computed.alias('siteSettings.credit_max_permit'),
  lastValidatedAt: null,

  @computed('model.username')
  bodyContent(username) {
    return I18n.t('credit.manage.body', { username, min: this.get('minCreditPermit'), max: this.get('maxCreditPermit') });
  },

  @computed('credit', 'lastValidatedAt')
  creditValidation(credit, lastValidatedAt) {
    let reason;
    if (Ember.isEmpty(credit)) {
      reason = I18n.t('credit.manage.error.missing');
    } else if (isNaN(credit) || parseInt(credit, 10) != credit) {
      reason = I18n.t('credit.manage.error.invalid');
    } else if (credit > this.get('maxCreditPermit') || credit < this.get('minCreditPermit')) {
      reason = I18n.t('credit.manage.error.not_in_range');
    }

    if (reason) {
      return InputValidation.create({ failed: true, reason, lastShownAt: lastValidatedAt });
    }
  },

  actions: {
    submit() {
      if (this.get('creditValidation')) {
        this.set('lastValidatedAt', Date.now());
        return;
      }
      ajax(`${Discourse.BaseUri}/discourse_credit/credits`, { method: 'POST', data: { credit: this.get('credit'), post_id: this.get('model.id') }}).then(json => {
        this.set('model.credit', json['credit']);
        this.send('closeModal');
      }).catch(error => {
        popupAjaxError(error);
      });
    }
  }
});