import { ajax } from 'discourse/lib/ajax';
import computed from "ember-addons/ember-computed-decorators";
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import User from 'discourse/models/user';

export default Ember.Controller.extend(ModalFunctionality, {
  credits: [],

  onShow() {
    ajax(`${Discourse.BaseUri}/discourse_credit/credits/${this.get('model.id')}`).then(json => {
      this.set('credits', json.credits.map(c => {
        return { credit: c.credit, user: User.create(c.user) }
      }));
    }).catch(error => {
      this.send('closeModal');
      popupAjaxError(error);
    });
  },

  actions: {
  }
});