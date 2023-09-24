import PropTypes from 'prop-types';

import { injectIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { debounce } from 'lodash';

import { fetchMentionedUsers, expandMentionedUsers } from 'mastodon/actions/interactions';
import ColumnHeader from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import ScrollableList from 'mastodon/components/scrollable_list';
import AccountContainer from 'mastodon/containers/account_container';
import Column from 'mastodon/features/ui/components/column';

const mapStateToProps = (state, props) => ({
  accountIds: state.getIn(['user_lists', 'mentioned_users', props.params.statusId, 'items']),
  hasMore: !!state.getIn(['user_lists', 'mentioned_users', props.params.statusId, 'next']),
  isLoading: state.getIn(['user_lists', 'mentioned_users', props.params.statusId, 'isLoading'], true),
});

class MentionedUsers extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    accountIds: ImmutablePropTypes.list,
    hasMore: PropTypes.bool,
    isLoading: PropTypes.bool,
    multiColumn: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  };

  UNSAFE_componentWillMount () {
    if (!this.props.accountIds) {
      this.props.dispatch(fetchMentionedUsers(this.props.params.statusId));
    }
  }

  handleLoadMore = debounce(() => {
    this.props.dispatch(expandMentionedUsers(this.props.params.statusId));
  }, 300, { leading: true });

  render () {
    const { accountIds, hasMore, isLoading, multiColumn } = this.props;

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.mentioned_users' defaultMessage='No one has been mentioned by this post.' />;

    return (
      <Column bindToDocument={!multiColumn}>
        <ColumnHeader
          showBackButton
          multiColumn={multiColumn}
        />

        <ScrollableList
          scrollKey='mentioned_users'
          onLoadMore={this.handleLoadMore}
          hasMore={hasMore}
          isLoading={isLoading}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        >
          {accountIds.map(id =>
            <AccountContainer key={id} id={id} withNote={false} />,
          )}
        </ScrollableList>

        <Helmet>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(MentionedUsers));
