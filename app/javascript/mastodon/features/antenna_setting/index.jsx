import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';


import { Helmet } from 'react-helmet';
import { withRouter } from 'react-router-dom';

import { List as ImmutableList, Map as ImmutableMap } from 'immutable';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';

import { ReactComponent as DeleteIcon } from '@material-symbols/svg-600/outlined/delete.svg';
import { ReactComponent as DomainIcon } from '@material-symbols/svg-600/outlined/dns.svg';
import { ReactComponent as EditIcon } from '@material-symbols/svg-600/outlined/edit.svg';
import { ReactComponent as HashtagIcon } from '@material-symbols/svg-600/outlined/tag.svg';
import { ReactComponent as KeywordIcon } from '@material-symbols/svg-600/outlined/title.svg';
import { ReactComponent as AntennaIcon } from '@material-symbols/svg-600/outlined/wifi.svg';
import Select, { NonceProvider } from 'react-select';
import Toggle from 'react-toggle';

import {
  fetchAntenna,
  deleteAntenna,
  updateAntenna,
  addDomainToAntenna,
  removeDomainFromAntenna,
  addExcludeDomainToAntenna,
  removeExcludeDomainFromAntenna,
  fetchAntennaDomains,
  fetchAntennaKeywords,
  removeKeywordFromAntenna,
  addKeywordToAntenna,
  removeExcludeKeywordFromAntenna,
  addExcludeKeywordToAntenna,
  fetchAntennaTags,
  removeTagFromAntenna,
  addTagToAntenna,
  removeExcludeTagFromAntenna,
  addExcludeTagToAntenna,
} from 'mastodon/actions/antennas';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { fetchLists } from 'mastodon/actions/lists';
import { openModal } from 'mastodon/actions/modal';
import { Button } from 'mastodon/components/button';
import Column from 'mastodon/components/column';
import ColumnHeader from 'mastodon/components/column_header';
import { Icon }  from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import BundleColumnError from 'mastodon/features/ui/components/bundle_column_error';
import { enableLocalTimeline } from 'mastodon/initial_state';
import { WithRouterPropTypes } from 'mastodon/utils/react_router';

import RadioPanel from './components/radio_panel';
import TextList from './components/text_list';

const messages = defineMessages({
  deleteMessage: { id: 'confirmations.delete_antenna.message', defaultMessage: 'Are you sure you want to permanently delete this antenna?' },
  deleteConfirm: { id: 'confirmations.delete_antenna.confirm', defaultMessage: 'Delete' },
  editAccounts: { id: 'antennas.edit_accounts', defaultMessage: 'Edit accounts' },
  noOptions: { id: 'antennas.select.no_options_message', defaultMessage: 'Empty lists' },
  placeholder: { id: 'antennas.select.placeholder', defaultMessage: 'Select list' },
  addDomainLabel: { id: 'antennas.add_domain_placeholder', defaultMessage: 'New domain' },
  addKeywordLabel: { id: 'antennas.add_keyword_placeholder', defaultMessage: 'New keyword' },
  addTagLabel: { id: 'antennas.add_tag_placeholder', defaultMessage: 'New tag' },
  addDomainTitle: { id: 'antennas.add_domain', defaultMessage: 'Add domain' },
  addKeywordTitle: { id: 'antennas.add_keyword', defaultMessage: 'Add keyword' },
  addTagTitle: { id: 'antennas.add_tag', defaultMessage: 'Add tag' },
  accounts: { id: 'antennas.accounts', defaultMessage: '{count} accounts' },
  domains: { id: 'antennas.domains', defaultMessage: '{count} domains' },
  tags: { id: 'antennas.tags', defaultMessage: '{count} tags' },
  keywords: { id: 'antennas.keywords', defaultMessage: '{count} keywords' },
  setHome: { id: 'antennas.select.set_home', defaultMessage: 'Set home' },
});

const mapStateToProps = (state, props) => ({
  antenna: state.getIn(['antennas', props.params.id]),
  lists: state.get('lists'),
  domains: state.getIn(['antennas', props.params.id, 'domains']) || ImmutableMap(),
  keywords: state.getIn(['antennas', props.params.id, 'keywords']) || ImmutableMap(),
  tags: state.getIn(['antennas', props.params.id, 'tags']) || ImmutableMap(),
});

class AntennaSetting extends PureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    columnId: PropTypes.string,
    multiColumn: PropTypes.bool,
    antenna: PropTypes.oneOfType([ImmutablePropTypes.map, PropTypes.bool]),
    lists: ImmutablePropTypes.map,
    domains: ImmutablePropTypes.map,
    keywords: ImmutablePropTypes.map,
    tags: ImmutablePropTypes.map,
    intl: PropTypes.object.isRequired,
    ...WithRouterPropTypes,
  };

  state = {
    domainName: '',
    excludeDomainName: '',
    keywordName: '',
    excludeKeywordName: '',
    tagName: '',
    excludeTagName: '',
    rangeRadioValue: null,
    contentRadioValue: null,
  };

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('ANTENNA', { id: this.props.params.id }));
      this.props.history.push('/');
    }
  };

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  };

  handleHeaderClick = () => {
    this.column.scrollTop();
  };

  componentDidMount () {
    const { dispatch } = this.props;
    const { id } = this.props.params;

    dispatch(fetchAntenna(id));
    dispatch(fetchAntennaDomains(id));
    dispatch(fetchAntennaKeywords(id));
    dispatch(fetchAntennaTags(id));
    dispatch(fetchLists());
  }

  UNSAFE_componentWillReceiveProps (nextProps) {
    const { dispatch } = this.props;
    const { id } = nextProps.params;

    if (id !== this.props.params.id) {
      dispatch(fetchAntenna(id));
      dispatch(fetchAntennaKeywords(id));
      dispatch(fetchAntennaDomains(id));
      dispatch(fetchAntennaKeywords(id));
      dispatch(fetchAntennaTags(id));
      dispatch(fetchLists());
    }
  }

  setRef = c => {
    this.column = c;
  };

  handleEditClick = () => {
    this.props.dispatch(openModal({
      modalType: 'ANTENNA_EDITOR',
      modalProps: { antennaId: this.props.params.id, isExclude: false },
    }));
  };

  handleExcludeEditClick = () => {
    this.props.dispatch(openModal({
      modalType: 'ANTENNA_EDITOR',
      modalProps: { antennaId: this.props.params.id, isExclude: true },
    }));
  };

  handleEditAntennaClick = () => {
    window.open(`/antennas/${this.props.params.id}/edit`, '_blank');
  };

  handleDeleteClick = () => {
    const { dispatch, columnId, intl } = this.props;
    const { id } = this.props.params;

    dispatch(openModal({
      modalType: 'CONFIRM',
      modalProps: {
        message: intl.formatMessage(messages.deleteMessage),
        confirm: intl.formatMessage(messages.deleteConfirm),
        onConfirm: () => {
          dispatch(deleteAntenna(id));

          if (columnId) {
            dispatch(removeColumn(columnId));
          } else {
            this.props.history.push('/antennasw');
          }
        },
      },
    }));
  };

  handleTimelineClick = () => {
    this.props.history.push(`/antennast/${this.props.params.id}`);
  };

  onStlToggle = ({ target }) => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, undefined, target.checked, undefined, undefined, undefined, undefined));
  };

  onLtlToggle = ({ target }) => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, undefined, undefined, target.checked, undefined, undefined, undefined));
  };

  onMediaOnlyToggle = ({ target }) => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, undefined, undefined, undefined, target.checked, undefined, undefined));
  };

  onIgnoreReblogToggle = ({ target }) => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, undefined, undefined, undefined, undefined, target.checked, undefined));
  };

  onNoInsertFeedsToggle = ({ target }) => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, undefined, undefined, undefined, undefined, undefined, target.checked));
  };

  onSelect = value => {
    const { dispatch } = this.props;
    const { id } = this.props.params;
    dispatch(updateAntenna(id, undefined, false, value.value, undefined, undefined, undefined, undefined, undefined));
  };

  onHomeSelect = () => this.onSelect({ value: '0' });

  noOptionsMessage = () => this.props.intl.formatMessage(messages.noOptions);

  onRangeRadioChanged = (value) => this.setState({ rangeRadioValue: value });

  onContentRadioChanged = (value) => this.setState({ contentRadioValue: value });

  onDomainNameChanged = (value) => this.setState({ domainName: value });

  onDomainAdd = () => {
    this.props.dispatch(addDomainToAntenna(this.props.params.id, this.state.domainName));
    this.setState({ domainName: '' });
  };

  onDomainRemove = (value) => this.props.dispatch(removeDomainFromAntenna(this.props.params.id, value));

  onKeywordNameChanged = (value) => this.setState({ keywordName: value });

  onKeywordAdd = () => {
    this.props.dispatch(addKeywordToAntenna(this.props.params.id, this.state.keywordName));
    this.setState({ keywordName: '' });
  };

  onKeywordRemove = (value) => this.props.dispatch(removeKeywordFromAntenna(this.props.params.id, value));

  onTagNameChanged = (value) => this.setState({ tagName: value });

  onTagAdd = () => {
    this.props.dispatch(addTagToAntenna(this.props.params.id, this.state.tagName));
    this.setState({ tagName: '' });
  };

  onTagRemove = (value) => this.props.dispatch(removeTagFromAntenna(this.props.params.id, value));

  onExcludeDomainNameChanged = (value) => this.setState({ excludeDomainName: value });

  onExcludeDomainAdd = () => {
    this.props.dispatch(addExcludeDomainToAntenna(this.props.params.id, this.state.excludeDomainName));
    this.setState({ excludeDomainName: '' });
  };

  onExcludeDomainRemove = (value) => this.props.dispatch(removeExcludeDomainFromAntenna(this.props.params.id, value));

  onExcludeKeywordNameChanged = (value) => this.setState({ excludeKeywordName: value });

  onExcludeKeywordAdd = () => {
    this.props.dispatch(addExcludeKeywordToAntenna(this.props.params.id, this.state.excludeKeywordName));
    this.setState({ excludeKeywordName: '' });
  };

  onExcludeKeywordRemove = (value) => this.props.dispatch(removeExcludeKeywordFromAntenna(this.props.params.id, value));

  onExcludeTagNameChanged = (value) => this.setState({ excludeTagName: value });

  onExcludeTagAdd = () => {
    this.props.dispatch(addExcludeTagToAntenna(this.props.params.id, this.state.excludeTagName));
    this.setState({ excludeTagName: '' });
  };

  onExcludeTagRemove = (value) => this.props.dispatch(removeExcludeTagFromAntenna(this.props.params.id, value));

  render () {
    const { columnId, multiColumn, antenna, lists, domains, keywords, tags, intl } = this.props;
    const { id } = this.props.params;
    const pinned = !!columnId;
    const title  = antenna ? antenna.get('title') : id;
    const isStl = antenna ? antenna.get('stl') : undefined;
    const isLtl = antenna ? antenna.get('ltl') : undefined;
    const isMediaOnly = antenna ? antenna.get('with_media_only') : undefined;
    const isIgnoreReblog = antenna ? antenna.get('ignore_reblog') : undefined;
    const isInsertFeeds = antenna ? antenna.get('insert_feeds') : undefined;

    if (typeof antenna === 'undefined') {
      return (
        <Column>
          <div className='scrollable'>
            <LoadingIndicator />
          </div>
        </Column>
      );
    } else if (antenna === false) {
      return (
        <BundleColumnError multiColumn={multiColumn} errorType='routing' />
      );
    }

    let columnSettings;
    if (!isStl && !isLtl) {
      columnSettings = (
        <>
          <div className='setting-toggle'>
            <Toggle id={`antenna-${id}-mediaonly`} checked={isMediaOnly} onChange={this.onMediaOnlyToggle} />
            <label htmlFor={`antenna-${id}-mediaonly`} className='setting-toggle__label'>
              <FormattedMessage id='antennas.media_only' defaultMessage='Media only' />
            </label>
          </div>

          <div className='setting-toggle'>
            <Toggle id={`antenna-${id}-ignorereblog`} checked={isIgnoreReblog} onChange={this.onIgnoreReblogToggle} />
            <label htmlFor={`antenna-${id}-ignorereblog`} className='setting-toggle__label'>
              <FormattedMessage id='antennas.ignore_reblog' defaultMessage='Exclude boosts' />
            </label>
          </div>
        </>
      );
    }

    let stlAlert;
    if (isStl) {
      stlAlert = (
        <div className='antenna-setting'>
          <p><FormattedMessage id='antennas.in_stl_mode' defaultMessage='This antenna is in STL mode.' /></p>
        </div>
      );
    } else if (isLtl) {
      stlAlert = (
        <div className='antenna-setting'>
          <p><FormattedMessage id='antennas.in_ltl_mode' defaultMessage='This antenna is in LTL mode.' /></p>
        </div>
      );
    }

    const rangeRadioValues = ImmutableList([
      ImmutableMap({ value: 'accounts', label: intl.formatMessage(messages.accounts, { count: antenna.get('accounts_count') }) }),
      ImmutableMap({ value: 'domains', label: intl.formatMessage(messages.domains, { count: antenna.get('domains_count') }) }),
    ]);
    const rangeRadioValue = ImmutableMap({ value: this.state.rangeRadioValue || (antenna.get('domains_count') > 0 ? 'domains' : 'accounts') });
    const rangeRadioAlert = antenna.get(rangeRadioValue.get('value') === 'accounts' ? 'domains_count' : 'accounts_count') > 0;

    const contentRadioValues = ImmutableList([
      ImmutableMap({ value: 'keywords', label: intl.formatMessage(messages.keywords, { count: antenna.get('keywords_count') }) }),
      ImmutableMap({ value: 'tags', label: intl.formatMessage(messages.tags, { count: antenna.get('tags_count') }) }),
    ]);
    const contentRadioValue = ImmutableMap({ value: this.state.contentRadioValue || (antenna.get('tags_count') > 0 ? 'tags' : 'keywords') });
    const contentRadioAlert = antenna.get(contentRadioValue.get('value') === 'tags' ? 'keywords_count' : 'tags_count') > 0;

    const listOptions = lists.toArray().filter((list) => list.length >= 2 && list[1]).map((list) => {
      return { value: list[1].get('id'), label: list[1].get('title') };
    });

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={title}>
        <ColumnHeader
          icon='wifi'
          iconComponent={AntennaIcon}
          title={title}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
        >
          <div className='column-settings__row column-header__links'>
            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleEditAntennaClick}>
              <Icon id='pencil' icon={EditIcon} /> <FormattedMessage id='antennas.edit_static' defaultMessage='Edit antenna' />
            </button>

            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleDeleteClick}>
              <Icon id='trash' icon={DeleteIcon} /> <FormattedMessage id='antennas.delete' defaultMessage='Delete antenna' />
            </button>

            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleTimelineClick}>
              <Icon id='wifi' icon={AntennaIcon} /> <FormattedMessage id='antennas.go_timeline' defaultMessage='Go to antenna timeline' />
            </button>
          </div>

          {!isLtl && (enableLocalTimeline || isStl) && (
            <div className='setting-toggle'>
              <Toggle id={`antenna-${id}-stl`} checked={isStl} onChange={this.onStlToggle} />
              <label htmlFor={`antenna-${id}-stl`} className='setting-toggle__label'>
                <FormattedMessage id='antennas.stl' defaultMessage='STL mode' />
              </label>
            </div>
          )}

          {!isStl && (enableLocalTimeline || isLtl) && (
            <div className='setting-toggle'>
              <Toggle id={`antenna-${id}-ltl`} checked={isLtl} onChange={this.onLtlToggle} />
              <label htmlFor={`antenna-${id}-ltl`} className='setting-toggle__label'>
                <FormattedMessage id='antennas.ltl' defaultMessage='LTL mode' />
              </label>
            </div>
          )}

          <div className='setting-toggle'>
            <Toggle id={`antenna-${id}-noinsertfeeds`} checked={isInsertFeeds} onChange={this.onNoInsertFeedsToggle} />
            <label htmlFor={`antenna-${id}-noinsertfeeds`} className='setting-toggle__label'>
              <FormattedMessage id='antennas.insert_feeds' defaultMessage='Insert to feeds' />
            </label>
          </div>

          {columnSettings}
        </ColumnHeader>

        {stlAlert}
        <div className='antenna-setting'>
          {isInsertFeeds && (
            <>
              {antenna.get('list') ? (
                <p><FormattedMessage id='antennas.related_list' defaultMessage='This antenna is related to {listTitle}.' values={{ listTitle: antenna.getIn(['list', 'title']) }} /></p>
              ) : (
                <p><FormattedMessage id='antennas.not_related_list' defaultMessage='This antenna is not related list. Posts will appear in home timeline. Open edit page to set list.' /></p>
              )}

              <NonceProvider nonce={document.querySelector('meta[name=style-nonce]').content} cacheKey='lists'>
                <Select
                  value={{ value: antenna.getIn(['list', 'id']), label: antenna.getIn(['list', 'title']) }}
                  options={listOptions}
                  noOptionsMessage={this.noOptionsMessage}
                  onChange={this.onSelect}
                  className='column-content-select__container'
                  classNamePrefix='column-content-select'
                  name='lists'
                  placeholder={this.props.intl.formatMessage(messages.placeholder)}
                  defaultOptions
                />
              </NonceProvider>

              <Button secondary text={this.props.intl.formatMessage(messages.setHome)} onClick={this.onHomeSelect} />
            </>
          )}

          {!isStl && !isLtl && (
            <>
              <h2><FormattedMessage id='antennas.filter' defaultMessage='Filter' /></h2>
              <RadioPanel values={rangeRadioValues} value={rangeRadioValue} onChange={this.onRangeRadioChanged} />

              {rangeRadioValue.get('value') === 'accounts' && <Button text={intl.formatMessage(messages.editAccounts)} onClick={this.handleEditClick} />}

              {rangeRadioValue.get('value') === 'domains' && (
                <TextList
                  onChange={this.onDomainNameChanged}
                  onAdd={this.onDomainAdd}
                  onRemove={this.onDomainRemove}
                  value={this.state.domainName}
                  values={domains.get('domains') || ImmutableList()}
                  icon='sitemap'
                  iconComponent={DomainIcon}
                  label={intl.formatMessage(messages.addDomainLabel)}
                  title={intl.formatMessage(messages.addDomainTitle)}
                />
              )}

              {rangeRadioAlert && <div className='alert'><FormattedMessage id='antennas.warnings.range_radio' defaultMessage='Simultaneous account and domain designation is not recommended.' /></div>}

              <RadioPanel values={contentRadioValues} value={contentRadioValue} onChange={this.onContentRadioChanged} />

              {contentRadioValue.get('value') === 'tags' && (
                <TextList
                  onChange={this.onTagNameChanged}
                  onAdd={this.onTagAdd}
                  onRemove={this.onTagRemove}
                  value={this.state.tagName}
                  values={tags.get('tags') || ImmutableList()}
                  icon='hashtag'
                  iconComponent={HashtagIcon}
                  label={intl.formatMessage(messages.addTagLabel)}
                  title={intl.formatMessage(messages.addTagTitle)}
                />
              )}

              {contentRadioValue.get('value') === 'keywords' && (
                <TextList
                  onChange={this.onKeywordNameChanged}
                  onAdd={this.onKeywordAdd}
                  onRemove={this.onKeywordRemove}
                  value={this.state.keywordName}
                  values={keywords.get('keywords') || ImmutableList()}
                  icon='paragraph'
                  iconComponent={KeywordIcon}
                  label={intl.formatMessage(messages.addKeywordLabel)}
                  title={intl.formatMessage(messages.addKeywordTitle)}
                />
              )}

              {contentRadioAlert && <div className='alert'><FormattedMessage id='antennas.warnings.content_radio' defaultMessage='Simultaneous keyword and tag designation is not recommended.' /></div>}

              <h2><FormattedMessage id='antennas.filter_not' defaultMessage='Filter Not' /></h2>
              <h3><FormattedMessage id='antennas.exclude_accounts' defaultMessage='Exclude accounts' /></h3>
              <Button text={intl.formatMessage(messages.editAccounts)} onClick={this.handleExcludeEditClick} />
              <h3><FormattedMessage id='antennas.exclude_domains' defaultMessage='Exclude domains' /></h3>
              <TextList
                onChange={this.onExcludeDomainNameChanged}
                onAdd={this.onExcludeDomainAdd}
                onRemove={this.onExcludeDomainRemove}
                value={this.state.excludeDomainName}
                values={domains.get('exclude_domains') || ImmutableList()}
                icon='sitemap'
                iconComponent={DomainIcon}
                label={intl.formatMessage(messages.addDomainLabel)}
                title={intl.formatMessage(messages.addDomainTitle)}
              />
              <h3><FormattedMessage id='antennas.exclude_keywords' defaultMessage='Exclude keywords' /></h3>
              <TextList
                onChange={this.onExcludeKeywordNameChanged}
                onAdd={this.onExcludeKeywordAdd}
                onRemove={this.onExcludeKeywordRemove}
                value={this.state.excludeKeywordName}
                values={keywords.get('exclude_keywords') || ImmutableList()}
                icon='paragraph'
                iconComponent={KeywordIcon}
                label={intl.formatMessage(messages.addKeywordLabel)}
                title={intl.formatMessage(messages.addKeywordTitle)}
              />
              <h3><FormattedMessage id='antennas.exclude_tags' defaultMessage='Exclude tags' /></h3>
              <TextList
                onChange={this.onExcludeTagNameChanged}
                onAdd={this.onExcludeTagAdd}
                onRemove={this.onExcludeTagRemove}
                value={this.state.excludeTagName}
                values={tags.get('exclude_tags') || ImmutableList()}
                icon='hashtag'
                iconComponent={HashtagIcon}
                label={intl.formatMessage(messages.addTagLabel)}
                title={intl.formatMessage(messages.addTagTitle)}
              />
            </>
          )}
        </div>

        <Helmet>
          <title>{title}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default withRouter(connect(mapStateToProps)(injectIntl(AntennaSetting)));
