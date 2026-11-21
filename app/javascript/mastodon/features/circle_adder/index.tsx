import { useEffect, useState, useCallback, useId } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import { UserCircleIcon, XIcon } from '@phosphor-icons/react';

import { Toggle } from '@/mastodon/components/form_fields';
import { fetchCircles } from 'mastodon/actions/circles';
import { createCircle } from 'mastodon/actions/circles_typed';
import {
  apiGetAccountCircles,
  apiAddAccountToCircle,
  apiRemoveAccountFromCircle,
} from 'mastodon/api/circles';
import type { ApiCircleJSON } from 'mastodon/api_types/circles';
import { Button, IconButton } from 'mastodon/components/button';
import { Icon } from 'mastodon/components/icon';
import { NavigationFocusTarget } from 'mastodon/components/navigation_focus_target';
import { getOrderedCircles } from 'mastodon/selectors/circles';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newItem: {
    id: 'circles.new_bookmark_category_name',
    defaultMessage: 'New bookmark_category name',
  },
  createCircle: {
    id: 'circles.create',
    defaultMessage: 'Create',
  },
  close: {
    id: 'lightbox.close',
    defaultMessage: 'Close',
  },
});

const CircleItem: React.FC<{
  id: string;
  title: string;
  checked: boolean;
  onChange: (id: string, checked: boolean) => void;
}> = ({ id, title, checked, onChange }) => {
  const uniqueId = useId();

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(id, e.target.checked);
    },
    [id, onChange],
  );

  return (
    <label className='lists__item' htmlFor={uniqueId}>
      <div className='lists__item__title'>
        <Icon id='list-ul' icon={UserCircleIcon} />
        <span>{title}</span>
      </div>

      <Toggle id={uniqueId} checked={checked} onChange={handleChange} />
    </label>
  );
};

const NewCircleItem: React.FC<{
  onCreate: (circle: ApiCircleJSON) => void;
}> = ({ onCreate }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const [title, setTitle] = useState('');

  const handleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    if (title.trim().length === 0) {
      return;
    }

    void dispatch(createCircle({ title })).then((result) => {
      if (isFulfilled(result)) {
        onCreate(result.payload);
        setTitle('');
      }

      return '';
    });
  }, [setTitle, dispatch, onCreate, title]);

  return (
    <form className='lists__item' onSubmit={handleSubmit}>
      <label className='lists__item__title'>
        <Icon id='list-ul' icon={UserCircleIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newItem)}
        />
      </label>

      <Button type='submit' variant='solid' color='accent' size='sm'>
        {intl.formatMessage(messages.createCircle)}
      </Button>
    </form>
  );
};

const CircleAdder: React.FC<{
  accountId: string;
  onClose: () => void;
}> = ({ accountId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const account = useAppSelector((state) => state.accounts.get(accountId));
  const circles = useAppSelector((state) => getOrderedCircles(state));
  const [circleIds, setCircleIds] = useState<string[]>([]);

  useEffect(() => {
    void dispatch(fetchCircles());

    apiGetAccountCircles(accountId)
      .then((data) => {
        setCircleIds(data.map((l) => l.id));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [dispatch, setCircleIds, accountId]);

  const handleToggle = useCallback(
    (circleId: string, checked: boolean) => {
      if (checked) {
        setCircleIds((currentCircleIds) => [circleId, ...currentCircleIds]);

        apiAddAccountToCircle(circleId, accountId).catch(() => {
          setCircleIds((currentCircleIds) =>
            currentCircleIds.filter((id) => id !== circleId),
          );
        });
      } else {
        setCircleIds((currentCircleIds) =>
          currentCircleIds.filter((id) => id !== circleId),
        );

        apiRemoveAccountFromCircle(circleId, accountId).catch(() => {
          setCircleIds((currentCircleIds) => [circleId, ...currentCircleIds]);
        });
      }
    },
    [setCircleIds, accountId],
  );

  const handleCreate = useCallback(
    (circle: ApiCircleJSON) => {
      setCircleIds((currentCircleIds) => [circle.id, ...currentCircleIds]);

      apiAddAccountToCircle(circle.id, accountId).catch(() => {
        setCircleIds((currentCircleIds) =>
          currentCircleIds.filter((id) => id !== circle.id),
        );
      });
    },
    [setCircleIds, accountId],
  );

  return (
    <div className='modal-root__modal dialog-modal'>
      <div className='dialog-modal__header'>
        <IconButton
          className='dialog-modal__header__close'
          icon={XIcon}
          onClick={onClose}
          size='sm'
          variant='ghost'
        >
          {intl.formatMessage(messages.close)}
        </IconButton>

        <NavigationFocusTarget as='h1' className='dialog-modal__header__title'>
          <FormattedMessage
            id='circles.add_to_bookmark_category'
            defaultMessage='Add {name} to circles'
            values={{ name: <strong>{account?.display_name}</strong> }}
          />
        </NavigationFocusTarget>
      </div>

      <div className='dialog-modal__content'>
        <div className='circles-scrollable'>
          <NewCircleItem onCreate={handleCreate} />

          {circles.map((circle) => (
            <CircleItem
              key={circle.id}
              id={circle.id}
              title={circle.title}
              checked={circleIds.includes(circle.id)}
              onChange={handleToggle}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default CircleAdder;
