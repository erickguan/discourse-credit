import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import InputValidation from 'discourse/models/input-validation';
import { ajax } from 'discourse/lib/ajax';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  init() {
    this._super();
    this._setupToll();
  },

  _setupToll() {
    this.setProperties({
      raw: '',
      credit: 10
    });
  },

  @computed('raw')
  contentValidation(raw) {
    if (Ember.isEmpty(raw)) {
      return InputValidation.create({ failed: true, reason: I18n.t('credit.toll_builder.content.invalid') });
    }
  },

  @computed('credit')
  creditValidation(credit) {
    if (parseInt(credit) <= 0) {
      return InputValidation.create({ failed: true, reason: I18n.t('credit.toll_builder.credit.invalid') });
    }
  },

  @computed('contentValidation', 'creditValidation')
  disableInsert(contentValidation, creditValidation) {
    return contentValidation || creditValidation;
  },

  actions: {
    insertCreditToll() {
      const credit = this.get('credit');
      ajax(`${Discourse.BaseUri}/discourse_credit/tolls`, { method: 'POST', data: { credit: credit, content: this.get('raw') }}).then(json => {
        let tollHeader = '[credit-toll';
        let output = '';
        //
        // const match = this.get('toolbarEvent').getText().match(/\[credit-toll(\s+credit=(\d+)]+)*.*\]/igm);
        //
        // if (match) {
        //   tollHeader += ` name=toll${match.length + 1}`;
        // }

        tollHeader += ` id=${json.id}`;
        tollHeader += ` credit=${credit}`;
        tollHeader += ']';
        output += `${tollHeader}\n`;
        output += `${this.siteSettings.credit_toll_instruction}\n`;
        output += '[/credit-toll]';

        this.get('toolbarEvent').addText(output);
      }).catch(error => {
        popupAjaxError(error);
      }).finally(() => {
        this.send('closeModal');
        this._setupToll();
      });

    }
  }
});
