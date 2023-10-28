import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePureComponent from 'react-immutable-pure-component';

import Column from 'mastodon/components/column';
import ComposeContainer from 'mastodon/containers/compose_container';

import NavigationContainer from '../compose/containers/navigation_container';

const messages = defineMessages({
  heading: { id: 'compose_form.publish', defaultMessage: 'Publish' },
});

class ComposePage extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
    multiColumn: PropTypes.bool,
  };

  render () {
    const { intl, multiColumn } = this.props;

    return (
      <Column bindToDocument={!multiColumn} label={intl.formatMessage(messages.heading)}>

        <NavigationContainer />
        <ComposeContainer />

        <Helmet>
          <title>{intl.formatMessage(messages.heading)}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default injectIntl(ComposePage);
