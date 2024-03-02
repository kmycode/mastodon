import { injectIntl, defineMessages } from 'react-intl';

import { connect } from 'react-redux';

import MarkdownIcon from '@/material-icons/400-24px/markdown.svg?react';
import { IconButton } from 'mastodon/components/icon_button';

import { changeComposeMarkdown } from '../../../actions/compose';

const messages = defineMessages({
  marked: { id: 'compose_form.markdown.marked', defaultMessage: 'Markdown is enabled' },
  unmarked: { id: 'compose_form.markdown.unmarked', defaultMessage: 'Markdown is disabled' },
});

const mapStateToProps = (state, { intl }) => ({
  iconComponent: MarkdownIcon,
  title: intl.formatMessage(state.getIn(['compose', 'markdown']) ? messages.marked : messages.unmarked),
  active: state.getIn(['compose', 'markdown']),
  ariaControls: 'cw-markdown-input',
  size: 18,
  inverted: true,
});

const mapDispatchToProps = dispatch => ({

  onClick () {
    dispatch(changeComposeMarkdown());
  },

});

export default injectIntl(connect(mapStateToProps, mapDispatchToProps)(IconButton));
