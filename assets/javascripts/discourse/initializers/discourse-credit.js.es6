import ApplicationController from 'discourse/controllers/application';
import ComposerController from 'discourse/controllers/composer';
import DiscourseURL from 'discourse/lib/url';
import { createWidget } from 'discourse/widgets/widget';
import { addButton } from 'discourse/widgets/post-menu';
import { iconNode } from 'discourse/helpers/fa-icon-node';
import { h } from 'virtual-dom';
import showModal from 'discourse/lib/show-modal';
import { withPluginApi } from 'discourse/lib/plugin-api';
import { observes } from 'ember-addons/ember-computed-decorators';

let _creditTollViews;

function createCreditTollView(container, post, tollId, tollCredit) {
  const controller = container.lookup("controller:credit-toll", { singleton: false });
  const view = container.lookup("view:credit-toll");

  controller.setProperties({ tollId, tollCredit, post });
  controller.refreshContent();

  view.set("controller", controller);

  return view;
}


function initializeWithApi(api) {
  const siteSettings = api.container.lookup('site-settings:main');

  // manage score menu
  api.attachWidgetAction('post-admin-menu', 'manageCredit', function(e) {
    showModal('admin-credit-management', {
      title: 'credit.manage.title',
      model: this.attrs
    });
  });
  api.decorateWidget('post-admin-menu:after', helper => {
    return helper.attach('post-admin-menu-button', {
      icon: 'calculator', label: 'credit.post_menu_button', action: 'manageCredit', className: 'manage-credit'
    });
  });

  // credit score shown in the post and list modal
  api.includePostAttributes('credit');
  api.attachWidgetAction('post', 'showPostCreditModal', function(e) {
    showModal('post-credit', {
      title: 'credit.post.title',
      model: this.attrs
    });
  });
  api.decorateWidget('post-meta-data:after', helper => {
    const args = helper.attrs;
    if (args.credit) {
      args.contents = () => args.credit > 0 ? `+${args.credit}` : `${args.credit}`;
      args.className = args.credit > 0 ? 'text-successful' : 'text-danger';
      args.action = 'showPostCreditModal';

      return helper.attach('link', args);
    }

  });

  // toolbar
  const ComposerController = api.container.lookupFactory('controller:composer');
  ComposerController.reopen({
    actions: {
      showCreditTollBuilder() {
        showModal('credit-toll-builder', {
          title: 'credit.toll_builder.title',
          model: this.get('model')
        }).set('toolbarEvent', this.get('toolbarEvent'));
      }
    }
  });
  api.addToolbarPopupMenuOptionsCallback(function() {
    return {
      action: 'showCreditTollBuilder',
      icon: 'money',
      label: 'credit.toll_builder.title'
    };
  });

  // decoration
  function cleanUpCreditTollViews() {
    if (_creditTollViews) {
      Object.keys(_creditTollViews).forEach(tollId => _creditTollViews[tollId].destroy());
    }
    _creditTollViews = null;
  }

  function createCreditTollViews($elem, helper) {
    const $creditTolls = $('.credit-toll', $elem);
    if (!$creditTolls.length) { return; }

    const post = helper.getModel();
    api.preventCloak(post.id);

    const postCreditTollViews = {};

    $creditTolls.each((idx, tollElem) => {
      const $div = $("<div>");
      const $toll = $(tollElem);

      const tollId = $toll.data("credit-toll-id");
      const tollCredit = $toll.data("credit-toll-credit");

      const tollView = createCreditTollView(
        helper.container,
        post,
        tollId,
        tollCredit
      );

      $toll.replaceWith($div);
      Em.run.schedule('afterRender', () => tollView.renderer.replaceIn(tollView, $div[0]));
      postCreditTollViews[tollId] = tollView;
    });

    _creditTollViews = postCreditTollViews;
  }

  api.decorateCooked(createCreditTollViews, { onlyStream: true });
  api.cleanupStream(cleanUpCreditTollViews);
}

export default {
  name: 'discourse-credit',

  initialize() {
    withPluginApi('0.5', initializeWithApi);
  }
};
