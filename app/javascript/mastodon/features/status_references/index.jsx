import PropTypes from 'prop-types';

import { injectIntl } from '@/mastodon/components/intl';
import { defineMessages, FormattedMessage } from 'react-intl';

import { Helmet } from '@unhead/react/helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { ArrowClockwiseIcon } from '@phosphor-icons/react';
import { fetchStatusReferences } from 'mastodon/actions/interactions';
import { ColumnHeader } from '@/mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { Column } from 'mastodon/components/column';
import StatusList from '@/mastodon/components/status_list';


const messages = defineMessages({
  refresh: { id: 'refresh', defaultMessage: 'Refresh' },
});

const mapStateToProps = (state, props) => ({
  accountIds: state.getIn(['user_lists', 'referred_by', props.params.statusId]),
});

class StatusReferences extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    accountIds: ImmutablePropTypes.list,
    multiColumn: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  };

  UNSAFE_componentWillMount () {
    if (!this.props.accountIds) {
      this.props.dispatch(fetchStatusReferences(this.props.params.statusId));
    }
  }

  UNSAFE_componentWillReceiveProps (nextProps) {
    if (nextProps.params.statusId !== this.props.params.statusId && nextProps.params.statusId) {
      this.props.dispatch(fetchStatusReferences(nextProps.params.statusId));
    }
  }

  handleRefresh = () => {
    this.props.dispatch(fetchStatusReferences(this.props.params.statusId));
  };

  render () {
    const { intl, accountIds, multiColumn } = this.props;

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.status_references' defaultMessage='No one has referred this post yet. When someone does, they will show up here.' />;

    return (
      <Column bindToDocument={!multiColumn}>
        <ColumnHeader
          withBackButton
          extraButtons={(
            <ColumnHeaderButton icon={ArrowClockwiseIcon} onClick={handleRefresh}>
              {intl.formatMessage(messages.refresh)}
            </ColumnHeaderButton>
          )}
        />

        <StatusList
          scrollKey='references_timeline'
          statusIds={accountIds}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        />

        <Helmet>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(StatusReferences));
