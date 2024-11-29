import { useEffect, useState, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import classNames from 'classnames';
import { useParams, Link } from 'react-router-dom';

import DeleteIcon from '@/material-icons/400-24px/delete.svg?react';
import DomainIcon from '@/material-icons/400-24px/dns.svg?react';
import HashtagIcon from '@/material-icons/400-24px/tag.svg?react';
import KeywordIcon from '@/material-icons/400-24px/title.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchAntenna } from 'mastodon/actions/antennas';
import {
  apiGetAccounts,
  apiGetDomains,
  apiAddDomain,
  apiRemoveDomain,
  apiGetTags,
  apiAddTag,
  apiRemoveTag,
  apiGetKeywords,
  apiAddKeyword,
  apiRemoveKeyword,
  apiAddExcludeDomain,
  apiRemoveExcludeDomain,
  apiAddExcludeTag,
  apiRemoveExcludeTag,
  apiAddExcludeKeyword,
  apiRemoveExcludeKeyword,
  apiGetExcludeAccounts,
} from 'mastodon/api/antennas';
import { Button } from 'mastodon/components/button';
import Column from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import type { IconProp } from 'mastodon/components/icon';
import { Icon } from 'mastodon/components/icon';
import { IconButton } from 'mastodon/components/icon_button';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  deleteMessage: {
    id: 'confirmations.delete_antenna.message',
    defaultMessage: 'Are you sure you want to permanently delete this antenna?',
  },
  deleteConfirm: {
    id: 'confirmations.delete_antenna.confirm',
    defaultMessage: 'Delete',
  },
  editAccounts: {
    id: 'antennas.edit_accounts',
    defaultMessage: 'Edit accounts',
  },
  noOptions: {
    id: 'antennas.select.no_options_message',
    defaultMessage: 'Empty lists',
  },
  placeholder: {
    id: 'antennas.select.placeholder',
    defaultMessage: 'Select list',
  },
  addDomainLabel: {
    id: 'antennas.add_domain_placeholder',
    defaultMessage: 'New domain',
  },
  addKeywordLabel: {
    id: 'antennas.add_keyword_placeholder',
    defaultMessage: 'New keyword',
  },
  addTagLabel: {
    id: 'antennas.add_tag_placeholder',
    defaultMessage: 'New tag',
  },
  addDomainTitle: { id: 'antennas.add_domain', defaultMessage: 'Add domain' },
  addKeywordTitle: {
    id: 'antennas.add_keyword',
    defaultMessage: 'Add keyword',
  },
  addTagTitle: { id: 'antennas.add_tag', defaultMessage: 'Add tag' },
  accounts: { id: 'antennas.accounts', defaultMessage: '{count} accounts' },
  domains: { id: 'antennas.domains', defaultMessage: '{count} domains' },
  tags: { id: 'antennas.tags', defaultMessage: '{count} tags' },
  keywords: { id: 'antennas.keywords', defaultMessage: '{count} keywords' },
  setHome: { id: 'antennas.select.set_home', defaultMessage: 'Set home' },
});

const TextListItem: React.FC<{
  icon: string;
  iconComponent: IconProp;
  value: string;
  onRemove: (value: string) => void;
}> = ({ icon, iconComponent, value, onRemove }) => {
  const handleRemove = useCallback(() => {
    onRemove(value);
  }, [onRemove, value]);

  return (
    <div className='setting-text-list-item'>
      <Icon id={icon} icon={iconComponent} />
      <span className='label'>{value}</span>
      <IconButton
        title='Delete'
        icon='trash'
        iconComponent={DeleteIcon}
        onClick={handleRemove}
      />
    </div>
  );
};

const TextList: React.FC<{
  values: string[];
  disabled?: boolean;
  icon: string;
  iconComponent: IconProp;
  label: string;
  title: string;
  onAdd: (value: string) => void;
  onRemove: (value: string) => void;
}> = ({
  values,
  disabled,
  icon,
  iconComponent,
  label,
  title,
  onAdd,
  onRemove,
}) => {
  const [value, setValue] = useState('');

  const handleValueChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setValue(value);
    },
    [setValue],
  );

  const handleAdd = useCallback(() => {
    onAdd(value);
    setValue('');
  }, [onAdd, value]);

  const handleRemove = useCallback(
    (removeValue: string) => {
      onRemove(removeValue);
    },
    [onRemove],
  );

  const handleSubmit = handleAdd;

  return (
    <div className='setting-text-list'>
      <form className='add-text-form' onSubmit={handleSubmit}>
        <label>
          <span style={{ display: 'none' }}>{label}</span>

          <input
            className='setting-text'
            value={value}
            disabled={disabled}
            onChange={handleValueChange}
            placeholder={label}
          />
        </label>

        <Button
          disabled={disabled || !value}
          text={title}
          onClick={handleAdd}
        />
      </form>

      {values.map((val) => (
        <TextListItem
          key={val}
          value={val}
          icon={icon}
          iconComponent={iconComponent}
          onRemove={handleRemove}
        />
      ))}
    </div>
  );
};

const RadioPanel: React.FC<{
  antennaId: string;
  items: { title: string; value: string }[];
  valueLengths: number[];
  alertMessage: React.ReactElement;
  onChange: (value: string) => void;
}> = ({ antennaId, items, valueLengths, alertMessage, onChange }) => {
  const [error, setError] = useState(false);
  const [value, setValue] = useState('');
  const [lastAntennaId, setLastAntennaId] = useState('');

  useEffect(() => {
    if (valueLengths.length >= 2) {
      setError(valueLengths.filter((v) => v > 0).length > 1);
    } else {
      setError(false);
    }
  }, [valueLengths]);

  useEffect(() => {
    if (
      items.length > 0 &&
      valueLengths.length === items.length &&
      antennaId !== lastAntennaId
    ) {
      for (let i = 0; i < valueLengths.length; i++) {
        const length = valueLengths[i] ?? 0;
        const item = items[i] ?? { value: '' };
        if (length > 0) {
          setValue(item.value);
          onChange(item.value);
          return;
        }
      }
      setValue(items[0]?.value ?? '');
    }
  }, [antennaId, lastAntennaId, items, valueLengths, setValue, onChange]);

  const handleChange = useCallback(
    ({ currentTarget }: React.MouseEvent<HTMLButtonElement>) => {
      const selected = currentTarget.getAttribute('data-value') ?? '';
      if (value !== selected) {
        onChange(selected);
        setValue(selected);

        // Set the flag for the first manual tab change.
        setLastAntennaId(antennaId);
      }
    },
    [value, setValue, onChange, setLastAntennaId, antennaId],
  );

  return (
    <div>
      <div className='setting-radio-panel'>
        {items.map((item) => (
          <button
            className={classNames('setting-radio-panel__item', {
              'setting-radio-panel__item__active': value === item.value,
            })}
            key={item.value}
            onClick={handleChange}
            data-value={item.value}
          >
            {item.title}
          </button>
        ))}
      </div>

      {error && <div className='alert'>{alertMessage}</div>}
    </div>
  );
};

const MembersLink: React.FC<{
  id: string;
  isExclude: boolean;
  onCountFetched?: (count: number) => void;
}> = ({ id, isExclude, onCountFetched }) => {
  const [count, setCount] = useState(0);
  const [avatars, setAvatars] = useState<string[]>([]);

  useEffect(() => {
    const api = isExclude ? apiGetExcludeAccounts : apiGetAccounts;
    void api(id)
      .then((data) => {
        setCount(data.length);
        if (onCountFetched) {
          onCountFetched(data.length);
        }
        setAvatars(data.slice(0, 3).map((a) => a.avatar));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [id, setCount, setAvatars, isExclude, onCountFetched]);

  return (
    <Link
      to={`/antennas/${id}/${isExclude ? 'exclude_members' : 'members'}`}
      className='app-form__link'
    >
      <div className='app-form__link__text'>
        <strong>
          <FormattedMessage
            id='antennas.antenna_accounts'
            defaultMessage='Antenna accounts'
          />
        </strong>
        <FormattedMessage
          id='antennas.antenna_accounts_count'
          defaultMessage='{count, plural, one {# member} other {# accounts}}'
          values={{ count }}
        />
      </div>

      <div className='avatar-pile'>
        {avatars.map((url) => (
          <img key={url} src={url} alt='' />
        ))}
      </div>
    </Link>
  );
};

const AntennaSetting: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id?: string }>();
  const intl = useIntl();
  //const history = useHistory();

  const antenna = useAppSelector((state) =>
    id ? state.antennas.get(id) : undefined,
  );
  const [domainList, setDomainList] = useState([] as string[]);
  const [excludeDomainList, setExcludeDomainList] = useState([] as string[]);
  const [tagList, setTagList] = useState([] as string[]);
  const [excludeTagList, setExcludeTagList] = useState([] as string[]);
  const [keywordList, setKeywordList] = useState([] as string[]);
  const [excludeKeywordList, setExcludeKeywordList] = useState([] as string[]);
  const [accountsCount, setAccountsCount] = useState(0);
  const [rangeMode, setRangeMode] = useState('accounts');
  const [contentMode, setContentMode] = useState('keywords');

  useEffect(() => {
    if (id) {
      dispatch(fetchAntenna(id));

      void apiGetDomains(id).then((data) => {
        setDomainList(data.domains);
        setExcludeDomainList(data.exclude_domains);
        return true;
      });

      void apiGetTags(id).then((data) => {
        setTagList(data.tags);
        setExcludeTagList(data.exclude_tags);
        return true;
      });

      void apiGetKeywords(id).then((data) => {
        setKeywordList(data.keywords);
        setExcludeKeywordList(data.exclude_keywords);
        return true;
      });
    }
  }, [
    dispatch,
    id,
    setDomainList,
    setExcludeDomainList,
    setTagList,
    setExcludeTagList,
    setKeywordList,
    setExcludeKeywordList,
  ]);

  const handleAccountsFetched = useCallback(
    (count: number) => {
      setAccountsCount(count);
    },
    [setAccountsCount],
  );

  const handleAddDomain = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddDomain(id, value).then(() => {
        setDomainList([...domainList, value]);
        return value;
      });
    },
    [id, domainList, setDomainList],
  );

  const handleRemoveDomain = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveDomain(id, value).then(() => {
        setDomainList(domainList.filter((v) => v !== value));
        return value;
      });
    },
    [id, domainList, setDomainList],
  );

  const handleAddExcludeDomain = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddExcludeDomain(id, value).then(() => {
        setExcludeDomainList([...excludeDomainList, value]);
        return value;
      });
    },
    [id, excludeDomainList, setExcludeDomainList],
  );

  const handleRemoveExcludeDomain = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveExcludeDomain(id, value).then(() => {
        setExcludeDomainList(excludeDomainList.filter((v) => v !== value));
        return value;
      });
    },
    [id, excludeDomainList, setExcludeDomainList],
  );

  const handleAddTag = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddTag(id, value).then(() => {
        setTagList([...tagList, value]);
        return value;
      });
    },
    [id, tagList, setTagList],
  );

  const handleRemoveTag = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveTag(id, value).then(() => {
        setTagList(tagList.filter((v) => v !== value));
        return value;
      });
    },
    [id, tagList, setTagList],
  );

  const handleAddExcludeTag = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddExcludeTag(id, value).then(() => {
        setExcludeTagList([...excludeTagList, value]);
        return value;
      });
    },
    [id, excludeTagList, setExcludeTagList],
  );

  const handleRemoveExcludeTag = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveExcludeTag(id, value).then(() => {
        setExcludeTagList(excludeTagList.filter((v) => v !== value));
        return value;
      });
    },
    [id, excludeTagList, setExcludeTagList],
  );

  const handleAddKeyword = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddKeyword(id, value).then(() => {
        setKeywordList([...keywordList, value]);
        return value;
      });
    },
    [id, keywordList, setKeywordList],
  );

  const handleRemoveKeyword = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveKeyword(id, value).then(() => {
        setKeywordList(keywordList.filter((v) => v !== value));
        return value;
      });
    },
    [id, keywordList, setKeywordList],
  );

  const handleAddExcludeKeyword = useCallback(
    (value: string) => {
      if (!id) return;

      void apiAddExcludeKeyword(id, value).then(() => {
        setExcludeKeywordList([...excludeKeywordList, value]);
        return value;
      });
    },
    [id, excludeKeywordList, setExcludeKeywordList],
  );

  const handleRemoveExcludeKeyword = useCallback(
    (value: string) => {
      if (!id) return;

      void apiRemoveExcludeKeyword(id, value).then(() => {
        setExcludeKeywordList(excludeKeywordList.filter((v) => v !== value));
        return value;
      });
    },
    [id, excludeKeywordList, setExcludeKeywordList],
  );

  const handleRangeRadioChange = useCallback(
    (value: string) => {
      setRangeMode(value);
    },
    [setRangeMode],
  );

  const handleContentRadioChange = useCallback(
    (value: string) => {
      setContentMode(value);
    },
    [setContentMode],
  );

  if (!antenna || !id) return <div />;

  if (antenna.stl)
    return (
      <div className='antenna-setting'>
        <p>
          <FormattedMessage
            id='antennas.in_stl_mode'
            defaultMessage='This antenna is in STL mode.'
          />
        </p>
      </div>
    );

  if (antenna.ltl)
    return (
      <div className='antenna-setting'>
        <p>
          <FormattedMessage
            id='antennas.in_ltl_mode'
            defaultMessage='This antenna is in LTL mode.'
          />
        </p>
      </div>
    );

  const rangeRadioItems = [
    {
      value: 'accounts',
      title: intl.formatMessage(messages.accounts, { count: accountsCount }),
    },
    {
      value: 'domains',
      title: intl.formatMessage(messages.domains, { count: domainList.length }),
    },
  ];
  const rangeRadioLengths = [accountsCount, domainList.length];

  const contentRadioItems = [
    {
      value: 'keywords',
      title: intl.formatMessage(messages.keywords, {
        count: keywordList.length,
      }),
    },
    {
      value: 'tags',
      title: intl.formatMessage(messages.tags, { count: tagList.length }),
    },
  ];
  const contentRadioLengths = [keywordList.length, tagList.length];

  return (
    <Column bindToDocument={!multiColumn} label={antenna.title}>
      <ColumnHeader
        title={antenna.title}
        icon='antenna-ul'
        iconComponent={AntennaIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable antenna-setting'>
        <RadioPanel
          antennaId={id}
          items={rangeRadioItems}
          valueLengths={rangeRadioLengths}
          alertMessage={
            <div className='alert'>
              <FormattedMessage
                id='antennas.warnings.range_radio'
                defaultMessage='Simultaneous account and domain designation is not recommended.'
              />
            </div>
          }
          onChange={handleRangeRadioChange}
        />
        {rangeMode === 'accounts' && (
          <MembersLink
            id={id}
            onCountFetched={handleAccountsFetched}
            isExclude={false}
          />
        )}
        {rangeMode === 'domains' && (
          <TextList
            values={domainList}
            icon='sitemap'
            iconComponent={DomainIcon}
            label={intl.formatMessage(messages.addDomainLabel)}
            title={intl.formatMessage(messages.addDomainTitle)}
            onAdd={handleAddDomain}
            onRemove={handleRemoveDomain}
          />
        )}

        <RadioPanel
          antennaId={id}
          items={contentRadioItems}
          valueLengths={contentRadioLengths}
          alertMessage={
            <div className='alert'>
              <FormattedMessage
                id='antennas.warnings.content_radio'
                defaultMessage='Simultaneous keyword and tag designation is not recommended.'
              />
            </div>
          }
          onChange={handleContentRadioChange}
        />
        {contentMode === 'keywords' && (
          <TextList
            values={keywordList}
            icon='paragraph'
            iconComponent={KeywordIcon}
            label={intl.formatMessage(messages.addKeywordLabel)}
            title={intl.formatMessage(messages.addKeywordTitle)}
            onAdd={handleAddKeyword}
            onRemove={handleRemoveKeyword}
          />
        )}
        {contentMode === 'tags' && (
          <TextList
            values={tagList}
            icon='hashtag'
            iconComponent={HashtagIcon}
            label={intl.formatMessage(messages.addTagLabel)}
            title={intl.formatMessage(messages.addTagTitle)}
            onAdd={handleAddTag}
            onRemove={handleRemoveTag}
          />
        )}

        <h2>
          <FormattedMessage
            id='antennas.filter_not'
            defaultMessage='Filter Not'
          />
        </h2>
        <h3>
          <FormattedMessage
            id='antennas.exclude_accounts'
            defaultMessage='Exclude accounts'
          />
        </h3>
        <MembersLink id={id} isExclude />
        <h3>
          <FormattedMessage
            id='antennas.exclude_domains'
            defaultMessage='Exclude domains'
          />
        </h3>
        <TextList
          values={excludeDomainList}
          icon='sitemap'
          iconComponent={DomainIcon}
          label={intl.formatMessage(messages.addDomainLabel)}
          title={intl.formatMessage(messages.addDomainTitle)}
          onAdd={handleAddExcludeDomain}
          onRemove={handleRemoveExcludeDomain}
        />
        <h3>
          <FormattedMessage
            id='antennas.exclude_keywords'
            defaultMessage='Exclude keywords'
          />
        </h3>
        <TextList
          values={excludeKeywordList}
          icon='paragraph'
          iconComponent={KeywordIcon}
          label={intl.formatMessage(messages.addKeywordLabel)}
          title={intl.formatMessage(messages.addKeywordTitle)}
          onAdd={handleAddExcludeKeyword}
          onRemove={handleRemoveExcludeKeyword}
        />
        <h3>
          <FormattedMessage
            id='antennas.exclude_tags'
            defaultMessage='Exclude tags'
          />
        </h3>
        <TextList
          values={excludeTagList}
          icon='paragraph'
          iconComponent={HashtagIcon}
          label={intl.formatMessage(messages.addTagLabel)}
          title={intl.formatMessage(messages.addTagTitle)}
          onAdd={handleAddExcludeTag}
          onRemove={handleRemoveExcludeTag}
        />
      </div>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default AntennaSetting;
